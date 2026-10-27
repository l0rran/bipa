import 'package:bipa/core/database/app_database.dart';
import 'package:bipa/core/money/money.dart';
import 'package:bipa/features/prices/domain/price_observation.dart';
import 'package:bipa/features/prices/domain/price_repository.dart';
import 'package:drift/drift.dart';

final class DriftPriceRepository implements PriceRepository {
  const DriftPriceRepository(this._db);

  final AppDatabase _db;

  @override
  Future<void> add(PriceObservation observation) async {
    await _db.into(_db.priceObservations).insert(
      PriceObservationsCompanion.insert(
        id: observation.id,
        productId: observation.productId,
        marketId: observation.marketId,
        priceCents: observation.price.cents,
        regularPriceCents: Value(observation.regularPrice?.cents),
        source: observation.source,
        observedAt: observation.observedAt,
        createdAt: observation.createdAt,
      ),
    );
  }

  @override
  Stream<List<PriceHistoryEntry>> watchHistory(String productId) {
    final prices = _db.priceObservations;
    final markets = _db.markets;

    final query = _db.select(prices).join([
      innerJoin(markets, markets.id.equalsExp(prices.marketId)),
    ])
      ..where(prices.productId.equals(productId))
      ..orderBy([OrderingTerm.desc(prices.observedAt)]);

    return query.watch().map(
      (rows) => [
        for (final row in rows)
          PriceHistoryEntry(
            observation: row.readTable(prices).toEntity(),
            marketName: row.readTable(markets).name,
          ),
      ],
    );
  }
}

extension PriceObservationRowMapper on PriceObservationRow {
  PriceObservation toEntity() {
    final regular = regularPriceCents;
    return PriceObservation(
      id: id,
      productId: productId,
      marketId: marketId,
      price: Money.cents(priceCents),
      regularPrice: regular == null ? null : Money.cents(regular),
      source: source,
      observedAt: observedAt,
      createdAt: createdAt,
    );
  }
}
