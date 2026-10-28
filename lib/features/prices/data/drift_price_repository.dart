import 'package:bipa/core/database/app_database.dart';
import 'package:bipa/core/money/money.dart';
import 'package:bipa/features/prices/domain/market_price.dart';
import 'package:bipa/features/prices/domain/price_condition.dart';
import 'package:bipa/features/prices/domain/price_observation.dart';
import 'package:bipa/features/prices/domain/price_repository.dart';
import 'package:bipa/features/products/data/product_mapper.dart';
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
    packageId: Value(observation.packageId),
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
    supersedesId: Value(observation.supersedes),
  );

  @override
  Stream<List<PriceHistoryEntry>> watchHistory(String productId) =>
      _watchHistoryWhere((prices) => prices.productId.equals(productId));

  @override
  Stream<List<PriceHistoryEntry>> watchHistoryOfProducts(Set<String> productIds) => productIds.isEmpty
      ? Stream.value(const [])
      : _watchHistoryWhere((prices) => prices.productId.isIn(productIds));

  @override
  Stream<Map<String, DateTime>> watchLatestPerMarket() {
    final prices = _db.priceObservations;
    final latest = prices.observedAt.max();
    final query = _db.selectOnly(prices)
      ..addColumns([prices.marketId, latest])
      ..groupBy([prices.marketId]);
    return query.watch().map(
      (rows) => {
        for (final row in rows)
          row.read(prices.marketId)!: ?row.read(latest),
      },
    );
  }

  @override
  Stream<List<MarketPrice>> watchLatestInMarket(String marketId) {
    final prices = _db.priceObservations;
    final products = _db.products;
    final packages = _db.productPackages;

    final query = _db.select(prices).join([
      innerJoin(products, products.id.equalsExp(prices.productId)),
      leftOuterJoin(packages, packages.id.equalsExp(prices.packageId)),
    ])
      ..where(prices.marketId.equals(marketId) & prices.conditionKind.equalsValue(PriceConditionKind.anyCustomer))
      ..orderBy([OrderingTerm.desc(prices.observedAt), OrderingTerm.desc(prices.createdAt)]);

    return query.watch().map((rows) {
      // Uma leitura corrigida não conta (ADR 0017); a correção está no mesmo
      // mercado, então vem na mesma consulta.
      final current = withoutSuperseded(rows, (row) => row.readTable(prices).toEntity());
      // Do mais recente para o mais antigo: o primeiro de cada produto e
      // embalagem é o que vale. O mapa guarda a ordem de chegada.
      final latest = <(String, String?), MarketPrice>{};
      for (final row in current) {
        final price = row.readTable(prices);
        latest.putIfAbsent(
          (price.productId, price.packageId),
          () => MarketPrice(
            observation: price.toEntity(),
            productName: row.readTable(products).name,
            package: row.readTableOrNull(packages)?.toEntity(),
          ),
        );
      }
      return latest.values.toList();
    });
  }

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
      (rows) => withoutSuperseded(
        [
          for (final row in rows)
            PriceHistoryEntry(
              observation: row.readTable(prices).toEntity(),
              marketName: row.readTable(markets).name,
            ),
        ],
        (entry) => entry.observation,
      ),
    );
  }
}

extension PriceObservationRowMapper on PriceObservationRow {
  PriceObservation toEntity() {
    final regular = regularPriceCents;
    return PriceObservation(
      id: id,
      productId: productId,
      packageId: packageId,
      marketId: marketId,
      price: Money.cents(priceCents),
      regularPrice: regular == null ? null : Money.cents(regular),
      condition: PriceCondition.from(conditionKind, minimumQuantity: minimumQuantity),
      source: source,
      observedAt: observedAt,
      createdAt: createdAt,
      supersedes: supersedesId,
    );
  }
}
