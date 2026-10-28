import 'package:bipa/core/database/app_database.dart';
import 'package:bipa/core/id/id_generator.dart';
import 'package:bipa/core/time/clock.dart';
import 'package:bipa/features/products/data/product_mapper.dart';
import 'package:bipa/features/stock/domain/stock_item.dart';
import 'package:bipa/features/stock/domain/stock_location.dart';
import 'package:bipa/features/stock/domain/stock_movement_reason.dart';
import 'package:bipa/features/stock/domain/stock_package.dart';
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
  Future<void> adjust({
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
      if (applied > 0) await _addToPackage(productId, packageId, applied, now);
      if (applied < 0) await _takeFromPackages(productId, packageId, -applied);
      if (applied != 0) {
        await _db.into(_db.stockMovements).insert(
          StockMovementsCompanion.insert(
            id: _ids.newId(),
            productId: productId,
            delta: applied,
            reason: reason,
            occurredAt: now,
          ),
        );
      }
    });
  }

  @override
  Stream<List<StockPackageCount>> watchPackages(String productId) {
    final counts = _db.stockPackages;
    final packages = _db.productPackages;
    final query = _db.select(counts).join([innerJoin(packages, packages.id.equalsExp(counts.packageId))])
      ..where(counts.productId.equals(productId) & counts.quantity.isBiggerThanValue(0))
      ..orderBy([OrderingTerm.asc(counts.since), OrderingTerm.asc(counts.packageId)]);
    return query.watch().map(
      (rows) => [
        for (final row in rows)
          StockPackageCount(
            package: row.readTable(packages).toEntity(),
            quantity: row.readTable(counts).quantity,
            since: row.readTable(counts).since,
          ),
      ],
    );
  }

  /// O que entra vai para a embalagem informada ou, sem ela, para a mais
  /// nova do produto. Produto sem embalagem só tem a contagem total.
  Future<void> _addToPackage(String productId, String? packageId, double amount, DateTime now) async {
    final target = packageId ?? await _newestPackageId(productId);
    if (target == null) return;
    final existing = await _selectPackage(productId, target).getSingleOrNull();
    if (existing == null || existing.quantity <= 0) {
      await _db.into(_db.stockPackages).insertOnConflictUpdate(
        StockPackagesCompanion.insert(productId: productId, packageId: target, quantity: amount, since: now),
      );
    } else {
      await (_db.update(_db.stockPackages)
            ..where((t) => t.productId.equals(productId) & t.packageId.equals(target)))
          .write(StockPackagesCompanion(quantity: Value(existing.quantity + amount)));
    }
  }

  /// O que sai sai primeiro da embalagem informada e depois da que está em
  /// casa há mais tempo. Uma embalagem que zera sai da tabela.
  Future<void> _takeFromPackages(String productId, String? packageId, double amount) async {
    final rows = await (_db.select(_db.stockPackages)
          ..where((t) => t.productId.equals(productId) & t.quantity.isBiggerThanValue(0))
          ..orderBy([(t) => OrderingTerm.asc(t.since), (t) => OrderingTerm.asc(t.packageId)]))
        .get();
    final ordered = [
      ...rows.where((row) => row.packageId == packageId),
      ...rows.where((row) => row.packageId != packageId),
    ];
    var remaining = amount;
    for (final row in ordered) {
      if (remaining <= 0) break;
      final taken = remaining < row.quantity ? remaining : row.quantity;
      remaining -= taken;
      final left = row.quantity - taken;
      if (left <= 1e-9) {
        await (_db.delete(_db.stockPackages)
              ..where((t) => t.productId.equals(productId) & t.packageId.equals(row.packageId)))
            .go();
      } else {
        await (_db.update(_db.stockPackages)
              ..where((t) => t.productId.equals(productId) & t.packageId.equals(row.packageId)))
            .write(StockPackagesCompanion(quantity: Value(left)));
      }
    }
  }

  Future<String?> _newestPackageId(String productId) async {
    final newest = await (_db.select(_db.productPackages)
          ..where((t) => t.productId.equals(productId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt), (t) => OrderingTerm.asc(t.id)])
          ..limit(1))
        .getSingleOrNull();
    return newest?.id;
  }

  SimpleSelectStatement<$StockPackagesTable, StockPackageRow> _selectPackage(String productId, String packageId) =>
      _db.select(_db.stockPackages)..where((t) => t.productId.equals(productId) & t.packageId.equals(packageId));

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
