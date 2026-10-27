import 'package:bipa/core/database/app_database.dart';
import 'package:bipa/core/location/geo_point.dart';
import 'package:bipa/core/money/money.dart';
import 'package:bipa/features/markets/data/drift_market_repository.dart';
import 'package:bipa/features/markets/domain/market.dart';
import 'package:bipa/features/prices/data/drift_price_repository.dart';
import 'package:bipa/features/prices/domain/price_observation.dart';
import 'package:bipa/features/prices/domain/price_source.dart';
import 'package:bipa/features/products/data/drift_product_repository.dart';
import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:bipa/features/products/domain/product.dart';
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

  PriceObservation observation(String id, String marketId, int cents, DateTime at, {int? regular}) =>
      PriceObservation(
        id: id,
        productId: 'leite',
        marketId: marketId,
        price: Money.cents(cents),
        regularPrice: regular == null ? null : Money.cents(regular),
        source: PriceSource.priceTag,
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

  test('mercados preservam a localização opcional', () async {
    final all = await markets.all();

    expect(all.map((m) => m.name), ['Atacarejo', 'Mercado do Bairro']);
    expect(all.first.location, isNull);
    expect(all.last.location, const GeoPoint(latitude: -23.55, longitude: -46.63));
  });
}
