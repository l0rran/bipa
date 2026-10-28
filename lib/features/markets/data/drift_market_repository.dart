import 'package:bipa/core/database/app_database.dart';
import 'package:bipa/core/location/geo_point.dart';
import 'package:bipa/features/markets/domain/market.dart';
import 'package:bipa/features/markets/domain/market_repository.dart';
import 'package:drift/drift.dart';

final class DriftMarketRepository implements MarketRepository {
  const DriftMarketRepository(this._db);

  final AppDatabase _db;

  SimpleSelectStatement<$MarketsTable, MarketRow> _orderedByName() =>
      _db.select(_db.markets)..orderBy([(t) => OrderingTerm.asc(t.name.lower())]);

  @override
  Stream<List<Market>> watchAll() =>
      _orderedByName().watch().map((rows) => [for (final row in rows) row.toEntity()]);

  @override
  Future<List<Market>> all() async =>
      [for (final row in await _orderedByName().get()) row.toEntity()];

  @override
  Future<Market?> findById(String id) async {
    final select = _db.select(_db.markets)..where((t) => t.id.equals(id));
    return (await select.getSingleOrNull())?.toEntity();
  }

  @override
  Future<void> save(Market market) async {
    await _db.into(_db.markets).insertOnConflictUpdate(
      MarketsCompanion.insert(
        id: market.id,
        name: market.name,
        address: Value(market.address),
        latitude: Value(market.location?.latitude),
        longitude: Value(market.location?.longitude),
        createdAt: market.createdAt,
        updatedAt: market.updatedAt,
        // Toda alteração marca o mercado como pendente de sincronização.
        syncedAt: const Value(null),
      ),
    );
  }

  @override
  Future<void> delete(String id) async {
    // Preços e ordem das seções apagam em cascata; as compras ficam sem
    // mercado (chaves estrangeiras).
    await (_db.delete(_db.markets)..where((t) => t.id.equals(id))).go();
  }
}

extension MarketRowMapper on MarketRow {
  Market toEntity() {
    final lat = latitude;
    final lng = longitude;
    return Market(
      id: id,
      name: name,
      address: address,
      location: lat != null && lng != null ? GeoPoint(latitude: lat, longitude: lng) : null,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}