import 'package:bipa/core/database/app_database.dart';
import 'package:bipa/core/id/id_generator.dart';
import 'package:bipa/core/time/clock.dart';
import 'package:bipa/features/shopping_list/domain/shopping_trip.dart';
import 'package:drift/drift.dart';

final class DriftShoppingTripRepository implements ShoppingTripRepository {
  const DriftShoppingTripRepository(this._db, {required IdGenerator ids, required Clock clock})
    : _ids = ids,
      _clock = clock;

  final AppDatabase _db;
  final IdGenerator _ids;
  final Clock _clock;

  SimpleSelectStatement<$ShoppingTripsTable, ShoppingTripRow> _active() => _db.select(_db.shoppingTrips)
    ..where((t) => t.finishedAt.isNull())
    ..orderBy([(t) => OrderingTerm.desc(t.startedAt)])
    ..limit(1);

  @override
  Stream<ShoppingTrip?> watchActive() => _active().watchSingleOrNull().map((row) => row?.toEntity());

  @override
  Future<ShoppingTrip> start({String? marketId}) => _db.transaction(() async {
    final current = await _active().getSingleOrNull();
    if (current != null) return current.toEntity();

    final trip = ShoppingTrip(id: _ids.newId(), marketId: marketId, startedAt: _clock());
    await _db.into(_db.shoppingTrips).insert(
      ShoppingTripsCompanion.insert(id: trip.id, marketId: Value(marketId), startedAt: trip.startedAt),
    );
    return trip;
  });

  @override
  Future<void> setMarket(String tripId, String marketId) =>
      _write(tripId, ShoppingTripsCompanion(marketId: Value(marketId)));

  @override
  Future<void> finish(String tripId) => _write(tripId, ShoppingTripsCompanion(finishedAt: Value(_clock())));

  @override
  Future<void> reopen(String tripId) => _write(tripId, const ShoppingTripsCompanion(finishedAt: Value(null)));

  Future<void> _write(String tripId, ShoppingTripsCompanion changes) async {
    await (_db.update(_db.shoppingTrips)..where((t) => t.id.equals(tripId))).write(changes);
  }
}

extension ShoppingTripRowMapper on ShoppingTripRow {
  ShoppingTrip toEntity() => ShoppingTrip(id: id, marketId: marketId, startedAt: startedAt, finishedAt: finishedAt);
}
