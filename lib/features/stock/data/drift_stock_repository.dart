import 'dart:math' as math;

import 'package:bipa/core/database/app_database.dart';
import 'package:bipa/core/id/id_generator.dart';
import 'package:bipa/core/time/clock.dart';
import 'package:bipa/features/products/data/product_mapper.dart';
import 'package:bipa/features/products/domain/product_package.dart';
import 'package:bipa/features/stock/domain/stock_item.dart';
import 'package:bipa/features/stock/domain/stock_location.dart';
import 'package:bipa/features/stock/domain/stock_movement_reason.dart';
import 'package:bipa/features/stock/domain/stock_lot.dart';
import 'package:bipa/features/stock/domain/stock_repository.dart';
import 'package:drift/drift.dart';

final class DriftStockRepository implements StockRepository {
  const DriftStockRepository(this._db, {required IdGenerator ids, required Clock clock})
    : _ids = ids,
      _clock = clock;

  final AppDatabase _db;
  final IdGenerator _ids;
  final Clock _clock;

  @override
  Stream<List<StockEntry>> watchAll() {
    final items = _db.stockItems;
    final products = _db.products;

    final query = _db.select(items).join([
      innerJoin(products, products.id.equalsExp(items.productId)),
    ])..orderBy([OrderingTerm.asc(products.name.lower())]);

    return query.watch().map(
      (rows) => [
        for (final row in rows)
          StockEntry(
            item: row.readTable(items).toEntity(),
            product: row.readTable(products).toEntity(),
          ),
      ],
    );
  }

  @override
  Future<StockItem?> findByProduct(String productId) async =>
      (await _selectItem(productId).getSingleOrNull())?.toEntity();

  @override
  Future<StockChange> adjust({
    required String productId,
    required double delta,
    required StockMovementReason reason,
    String? packageId,
  }) {
    return _db.transaction(() async {
      final now = _clock();
      final current = await _selectItem(productId).getSingleOrNull();
      final previous = current?.quantity ?? 0.0;
      final quantity = StockItem.nextQuantity(previous, delta);

      if (current == null) {
        await _db.into(_db.stockItems).insert(
          StockItemsCompanion.insert(
            productId: productId,
            quantity: quantity,
            location: StockLocation.pantry,
            updatedAt: now,
          ),
        );
      } else {
        await _updateItem(
          productId,
          StockItemsCompanion(quantity: Value(quantity), updatedAt: Value(now)),
        );
      }

      // Registra o que de fato mudou (a quantidade não fica negativa).
      final applied = quantity - previous;
      final lots = <StockLotDelta>[
        if (applied > 0) await _addLot(productId, packageId, applied, now),
        if (applied < 0) ...await _takeFromLots(productId, -applied, packageId: packageId),
      ];
      if (applied != 0) await _recordMovement(productId, applied, reason, now);
      return StockChange(productId: productId, lots: lots);
    });
  }

  @override
  Future<void> revert(StockChange change) {
    if (change.isEmpty) return Future.value();
    return _db.transaction(() async {
      final now = _clock();
      final productId = change.productId;
      final current = await _selectItem(productId).getSingleOrNull();
      // O produto foi apagado ou juntado a outro: não há o que desfazer.
      if (current == null) return;

      var moved = 0.0;
      var alreadyUsed = 0.0;
      for (final lot in change.lots) {
        if (lot.delta > 0) {
          // Tira o lote que entrou; o que dele já foi usado sai de outro lote.
          final row = await _selectLot(lot.lotId).getSingleOrNull();
          final taken = math.min(lot.delta, row?.quantity ?? 0.0);
          if (row != null) await _setLotQuantity(row.id, row.quantity - taken);
          moved -= taken;
          alreadyUsed += lot.delta - taken;
        } else if (lot.delta < 0) {
          moved -= lot.delta;
          await _giveBack(productId, lot);
        }
      }
      if (alreadyUsed > _epsilon) {
        final taken = await _takeFromLots(productId, alreadyUsed);
        moved += taken.fold(0.0, (sum, lot) => sum + lot.delta);
      }
      if (moved.abs() <= _epsilon) return;

      final quantity = StockItem.nextQuantity(current.quantity, moved);
      await _updateItem(productId, StockItemsCompanion(quantity: Value(quantity), updatedAt: Value(now)));
      await _recordMovement(productId, quantity - current.quantity, StockMovementReason.adjustment, now);
    });
  }

  @override
  Stream<List<StockLot>> watchLots(String productId) {
    final lots = _db.stockLots;
    final packages = _db.productPackages;
    final query = _db.select(lots).join([leftOuterJoin(packages, packages.id.equalsExp(lots.packageId))])
      ..where(lots.productId.equals(productId) & lots.quantity.isBiggerThanValue(0))
      ..orderBy([OrderingTerm.asc(lots.since), OrderingTerm.asc(lots.id)]);
    return query.watch().map(
      (rows) => [
        for (final row in rows) row.readTable(lots).toEntity(package: row.readTableOrNull(packages)?.toEntity()),
      ],
    );
  }

  /// O que entra vira um lote da embalagem informada ou, sem ela, da mais
  /// nova do produto.
  Future<StockLotDelta> _addLot(String productId, String? packageId, double amount, DateTime now) async {
    final target = packageId ?? await _newestPackageId(productId);
    final id = _ids.newId();
    await _db.into(_db.stockLots).insert(
      StockLotsCompanion.insert(id: id, productId: productId, packageId: Value(target), quantity: amount, since: now),
    );
    return StockLotDelta(lotId: id, packageId: target, since: now, delta: amount);
  }

  /// Tira [amount] dos lotes, na ordem de [takeFromLots]. Um lote que zera
  /// sai da tabela.
  Future<List<StockLotDelta>> _takeFromLots(String productId, double amount, {String? packageId}) async {
    final rows = await (_db.select(_db.stockLots)..where((t) => t.productId.equals(productId))).get();
    final plan = takeFromLots([for (final row in rows) row.toEntity()], amount, packageId: packageId);
    for (final (:lot, :taken) in plan) {
      await _setLotQuantity(lot.id, lot.quantity - taken);
    }
    return [
      for (final (:lot, :taken) in plan)
        StockLotDelta(lotId: lot.id, packageId: lot.packageId, since: lot.since, delta: -taken),
    ];
  }

  /// Devolve o que saiu de um lote, recriando-o se ele tinha zerado.
  Future<void> _giveBack(String productId, StockLotDelta lot) async {
    final row = await _selectLot(lot.lotId).getSingleOrNull();
    if (row != null) {
      await _setLotQuantity(row.id, row.quantity - lot.delta);
      return;
    }
    // A embalagem pode ter sido apagada nesse meio-tempo.
    final packageId = lot.packageId;
    final packageExists = packageId != null &&
        await (_db.select(_db.productPackages)..where((t) => t.id.equals(packageId))).getSingleOrNull() != null;
    await _db.into(_db.stockLots).insert(
      StockLotsCompanion.insert(
        id: lot.lotId,
        productId: productId,
        packageId: Value(packageExists ? packageId : null),
        quantity: -lot.delta,
        since: lot.since,
      ),
    );
  }

  Future<void> _setLotQuantity(String lotId, double quantity) async {
    if (quantity <= _epsilon) {
      await (_db.delete(_db.stockLots)..where((t) => t.id.equals(lotId))).go();
    } else {
      await (_db.update(_db.stockLots)..where((t) => t.id.equals(lotId)))
          .write(StockLotsCompanion(quantity: Value(quantity)));
    }
  }

  Future<void> _recordMovement(String productId, double delta, StockMovementReason reason, DateTime now) =>
      _db.into(_db.stockMovements).insert(
        StockMovementsCompanion.insert(
          id: _ids.newId(),
          productId: productId,
          delta: delta,
          reason: reason,
          occurredAt: now,
        ),
      );

  Future<String?> _newestPackageId(String productId) async {
    final newest = await (_db.select(_db.productPackages)
          ..where((t) => t.productId.equals(productId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt), (t) => OrderingTerm.asc(t.id)])
          ..limit(1))
        .getSingleOrNull();
    return newest?.id;
  }

  SimpleSelectStatement<$StockLotsTable, StockLotRow> _selectLot(String id) =>
      _db.select(_db.stockLots)..where((t) => t.id.equals(id));

  @override
  Future<void> remove(String productId) => _db.transaction(() async {
    await (_db.delete(_db.stockLots)..where((t) => t.productId.equals(productId))).go();
    await (_db.delete(_db.stockItems)..where((t) => t.productId.equals(productId))).go();
  });

  @override
  // A coluna continua minimumQuantity no banco; no domínio é o "ter sempre".
  Future<void> setTargetQuantity(String productId, double? target) =>
      _upsertSettings(productId, StockItemsCompanion(minimumQuantity: Value(target)));

  @override
  Future<void> setLocation(String productId, StockLocation location) =>
      _upsertSettings(productId, StockItemsCompanion(location: Value(location)));

  /// Aplica configurações ao item, criando-o com quantidade zero se preciso.
  Future<void> _upsertSettings(String productId, StockItemsCompanion changes) {
    return _db.transaction(() async {
      final now = _clock();
      final exists = await _selectItem(productId).getSingleOrNull() != null;
      if (!exists) {
        await _db.into(_db.stockItems).insert(
          StockItemsCompanion.insert(
            productId: productId,
            quantity: 0,
            location: StockLocation.pantry,
            updatedAt: now,
          ),
        );
      }
      await _updateItem(productId, changes.copyWith(updatedAt: Value(now)));
    });
  }

  SimpleSelectStatement<$StockItemsTable, StockItemRow> _selectItem(String productId) =>
      _db.select(_db.stockItems)..where((t) => t.productId.equals(productId));

  Future<void> _updateItem(String productId, StockItemsCompanion changes) async {
    await (_db.update(_db.stockItems)..where((t) => t.productId.equals(productId)))
        .write(changes);
  }
}

extension StockItemRowMapper on StockItemRow {
  StockItem toEntity() => StockItem(
    productId: productId,
    quantity: quantity,
    targetQuantity: minimumQuantity,
    location: location,
    updatedAt: updatedAt,
  );
}

extension StockLotRowMapper on StockLotRow {
  StockLot toEntity({ProductPackage? package}) => StockLot(
    id: id,
    productId: productId,
    packageId: packageId,
    package: package,
    quantity: quantity,
    since: since,
  );
}

const _epsilon = 1e-9;
