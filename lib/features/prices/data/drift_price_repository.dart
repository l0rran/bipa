import 'package:bipa/core/database/app_database.dart';
import 'package:bipa/core/money/money.dart';
import 'package:bipa/features/prices/domain/price_condition.dart';
import 'package:bipa/features/prices/domain/price_observation.dart';
import 'package:bipa/features/prices/domain/price_repository.dart';
import 'package:drift/drift.dart';

final class DriftPriceRepository implements PriceRepository {
  const DriftPriceRepository(this._db);

  final AppDatabase _db;

  @override
  Future<void> add(PriceObservation observation) => addAll([observation]);

  @override
  Future<void> addAll(Iterable<PriceObservation> observations) => _db.batch((batch) {
    batch.insertAll(_db.priceObservations, [for (final observation in observations) _toCompanion(observation)]);
  });

  static PriceObservationsCompanion _toCompanion(PriceObservation observation) => PriceObservationsCompanion.insert(
    id: observation.id,
    productId: observation.productId,
    marketId: observation.marketId,
    priceCents: observation.price.cents,
    regularPriceCents: Value(observation.regularPrice?.cents),
    conditionKind: Value(observation.condition.kind),
    minimumQuantity: Value(switch (observation.condition) {
      Wholesale(:final minimumQuantity) => minimumQuantity,
      AnyCustomer() || LoyaltyMembers() => null,
    }),
    source: observation.source,
    observedAt: observation.observedAt,
    createdAt: observation.createdAt,
  );

  @override
  Stream<List<PriceHistoryEntry>> watchHistory(String productId) =>
      _watchHistoryWhere((prices) => prices.productId.equals(productId));

  @override
  Stream<List<PriceHistoryEntry>> watchHistoryOfProducts(Set<String> productIds) => productIds.isEmpty
      ? Stream.value(const [])
      : _watchHistoryWhere((prices) => prices.productId.isIn(productIds));

  Stream<List<PriceHistoryEntry>> _watchHistoryWhere(
    Expression<bool> Function($PriceObservationsTable prices) filter,
  ) {
    final prices = _db.priceObservations;
    final markets = _db.markets;

    final query = _db.select(prices).join([
      innerJoin(markets, markets.id.equalsExp(prices.marketId)),
    ])
      ..where(filter(prices))
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
      condition: PriceCondition.from(conditionKind, minimumQuantity: minimumQuantity),
      source: source,
      observedAt: observedAt,
      createdAt: createdAt,
    );
  }
}
