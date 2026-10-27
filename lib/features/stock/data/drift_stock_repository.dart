import 'package:bipa/core/database/app_database.dart';
import 'package:bipa/core/id/id_generator.dart';
import 'package:bipa/core/time/clock.dart';
import 'package:bipa/features/products/data/product_mapper.dart';
import 'package:bipa/features/stock/domain/stock_item.dart';
import 'package:bipa/features/stock/domain/stock_location.dart';
import 'package:bipa/features/stock/domain/stock_movement_reason.dart';
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
