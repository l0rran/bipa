import 'package:bipa/core/database/app_database.dart';
import 'package:bipa/core/location/geo_point.dart';
import 'package:bipa/core/money/money.dart';
import 'package:bipa/features/markets/data/drift_market_repository.dart';
import 'package:bipa/features/markets/domain/market.dart';
import 'package:bipa/features/prices/data/drift_price_repository.dart';
import 'package:bipa/features/prices/domain/price_condition.dart';
import 'package:bipa/features/prices/domain/price_observation.dart';
import 'package:bipa/features/prices/domain/price_source.dart';
import 'package:bipa/features/products/data/drift_product_repository.dart';
import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/products/domain/product_package.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DriftPriceRepository prices;
  late DriftMarketRepository markets;

  setUp(() async {
    db = createTestDatabase();
    prices = DriftPriceRepository(db);
    markets = DriftMarketRepository(db);

    final created = DateTime(2026);
    await DriftProductRepository(db).save(
      Product(id: 'leite', name: 'Leite', unit: MeasureUnit.liter, createdAt: created, updatedAt: created),
    );
    await markets.save(
      Market(
        id: 'm1',
        name: 'Mercado do Bairro',
        location: const GeoPoint(latitude: -23.55, longitude: -46.63),
        createdAt: created,
        updatedAt: created,
      ),
    );
    await markets.save(Market(id: 'm2', name: 'Atacarejo', createdAt: created, updatedAt: created));
  });

  tearDown(() => db.close());

  PriceObservation observation(
    String id,
    String marketId,
    int cents,
    DateTime at, {
    int? regular,
    PriceCondition condition = const AnyCustomer(),
  }) => PriceObservation(
    id: id,
    productId: 'leite',
    marketId: marketId,
    price: Money.cents(cents),
    regularPrice: regular == null ? null : Money.cents(regular),
    source: PriceSource.priceTag,
    condition: condition,
    observedAt: at,
    createdAt: at,
  );

  test('histórico vem do mais recente para o mais antigo, com o nome do mercado', () async {
    final antiga = observation('a', 'm1', 549, DateTime(2026, 10, 1));
    final recente = observation('b', 'm2', 499, DateTime(2026, 10, 20), regular: 599);
    await prices.add(antiga);
    await prices.add(recente);

    final history = await prices.watchHistory('leite').first;

    expect(history.map((e) => e.observation), [recente, antiga]);
    expect(history.map((e) => e.marketName), ['Atacarejo', 'Mercado do Bairro']);
    expect(history.first.observation.isPromotion, isTrue);
  });

  test('diz quando foi o preço mais recente de cada mercado', () async {
    await prices.addAll([
      observation('a', 'm1', 549, DateTime(2026, 10, 1)),
      observation('b', 'm1', 559, DateTime(2026, 10, 9)),
      observation('c', 'm2', 499, DateTime(2026, 10, 20)),
    ]);

    expect(await prices.watchLatestPerMarket().first, {'m1': DateTime(2026, 10, 9), 'm2': DateTime(2026, 10, 20)});
  });

  test('mostra o preço mais recente de cada produto e embalagem no mercado', () async {
    final created = DateTime(2026);
    await DriftProductRepository(db).savePackage(
      ProductPackage(
        id: 'leite-1l',
        productId: 'leite',
        brand: 'Itambé',
        size: 1,
        unit: MeasureUnit.liter,
        createdAt: created,
        updatedAt: created,
      ),
    );
    final semEmbalagem = observation('a', 'm1', 549, DateTime(2026, 10, 1));
    final antiga = PriceObservation(
      id: 'b',
      productId: 'leite',
      packageId: 'leite-1l',
      marketId: 'm1',
      price: Money.cents(519),
      source: PriceSource.priceTag,
      observedAt: DateTime(2026, 10, 2),
      createdAt: DateTime(2026, 10, 2),
    );
    final recente = PriceObservation(
      id: 'c',
      productId: 'leite',
      packageId: 'leite-1l',
      marketId: 'm1',
      price: Money.cents(499),
      source: PriceSource.priceTag,
      observedAt: DateTime(2026, 10, 9),
      createdAt: DateTime(2026, 10, 9),
    );
    await prices.addAll([
      semEmbalagem,
      antiga,
      recente,
      // O de cartão e o de outro mercado ficam de fora.
      observation('d', 'm1', 450, DateTime(2026, 10, 10), condition: const LoyaltyMembers()),
      observation('e', 'm2', 399, DateTime(2026, 10, 11)),
    ]);

    final latest = await prices.watchLatestInMarket('m1').first;

    expect(latest.map((p) => p.observation), [recente, semEmbalagem]);
    expect(latest.map((p) => p.productName), ['Leite', 'Leite']);
    expect(latest.first.package?.label, 'Itambé · 1 L');
    expect(latest.last.package, isNull);
  });

  test('grava e lê a condição de cada preço', () async {
    final at = DateTime(2026, 10, 27);
    final saved = [
      observation('varejo', 'm2', 805, at),
      observation('cartao', 'm2', 785, at, condition: const LoyaltyMembers()),
      observation('atacado', 'm2', 785, at, condition: const Wholesale(minimumQuantity: 10)),
      observation('atacado-sem-minimo', 'm2', 780, at, condition: const Wholesale()),
    ];
    for (final item in saved) {
      await prices.add(item);
    }

    final history = await prices.watchHistory('leite').first;

    expect(history.map((e) => e.observation).toSet(), saved.toSet());
  });

  test('mercados preservam a localização opcional', () async {
    final all = await markets.all();

    expect(all.map((m) => m.name), ['Atacarejo', 'Mercado do Bairro']);
    expect(all.first.location, isNull);
    expect(all.last.location, const GeoPoint(latitude: -23.55, longitude: -46.63));
  });
}
