import 'package:bipa/core/database/app_database.dart';
import 'package:bipa/core/money/money.dart';
import 'package:bipa/features/shopping_list/domain/trip_price.dart';
import 'package:drift/drift.dart';

final class DriftTripPriceRepository implements TripPriceRepository {
  const DriftTripPriceRepository(this._db);

  final AppDatabase _db;

  @override
  Future<List<TripPrice>> ofTrip(String tripId) async => (await _ofTrip(tripId).get()).map(_toEntity).toList();

  @override
  Stream<List<TripPrice>> watchTrip(String tripId) =>
      _ofTrip(tripId).watch().map((rows) => rows.map(_toEntity).toList());

  SimpleSelectStatement<$TripPricesTable, TripPriceRow> _ofTrip(String tripId) => _db.select(_db.tripPrices)
    ..where((t) => t.tripId.equals(tripId))
    ..orderBy([(t) => OrderingTerm.asc(t.readAt)]);

  @override
  Future<TripPrice?> find(String tripId, String itemKey) async {
    final row = await (_db.select(
      _db.tripPrices,
    )..where((t) => t.tripId.equals(tripId) & t.itemKey.equals(itemKey))).getSingleOrNull();
    return row == null ? null : _toEntity(row);
  }

  @override
  Future<void> save(TripPrice price) async {
    await _db
        .into(_db.tripPrices)
        .insertOnConflictUpdate(
          TripPricesCompanion.insert(
            tripId: price.tripId,
            itemKey: price.itemKey,
            productId: price.productId,
            packageId: Value(price.packageId),
            priceCents: price.price.cents,
            source: price.source,
            otherOffers: price.otherOffers,
            readAt: price.readAt,
            observationId: Value(price.observationId),
            marketId: Value(price.marketId),
            perKilo: Value(price.perKilo),
          ),
        );
  }

  static TripPrice _toEntity(TripPriceRow row) => TripPrice(
    tripId: row.tripId,
    productId: row.productId,
    packageId: row.packageId,
    price: Money.cents(row.priceCents),
    source: row.source,
    readAt: row.readAt,
    otherOffers: row.otherOffers,
    observationId: row.observationId,
    marketId: row.marketId,
    perKilo: row.perKilo,
  );
}
