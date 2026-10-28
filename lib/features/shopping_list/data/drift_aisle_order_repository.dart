import 'package:bipa/core/database/app_database.dart';
import 'package:bipa/features/shopping_list/domain/aisle_order.dart';
import 'package:drift/drift.dart';

final class DriftAisleOrderRepository implements AisleOrderRepository {
  const DriftAisleOrderRepository(this._db);

  final AppDatabase _db;

  SimpleSelectStatement<$MarketAislesTable, MarketAisleRow> _select(String marketId) =>
      _db.select(_db.marketAisles)..where((t) => t.marketId.equals(marketId));

  @override
  Stream<AisleOrder> watch(String marketId) => _select(marketId).watch().map(_toOrder);

  @override
  Future<AisleOrder> find(String marketId) async => _toOrder(await _select(marketId).get());

  @override
  Future<void> save(String marketId, AisleOrder order) => _db.transaction(() async {
    await (_db.delete(_db.marketAisles)..where((t) => t.marketId.equals(marketId))).go();
    await _db.batch(
      (batch) => batch.insertAll(_db.marketAisles, [
        for (final MapEntry(key: aisle, value: learned) in order.learned.entries)
          MarketAislesCompanion.insert(
            marketId: marketId,
            aisle: aisle,
            position: learned.position,
            samples: learned.samples,
          ),
      ]),
    );
  });

  static AisleOrder _toOrder(List<MarketAisleRow> rows) =>
      AisleOrder({for (final row in rows) row.aisle: LearnedAisle(position: row.position, samples: row.samples)});
}
