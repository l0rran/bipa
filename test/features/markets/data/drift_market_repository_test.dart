import 'package:bipa/core/catalog/product_kind.dart';
import 'package:bipa/core/database/app_database.dart';
import 'package:bipa/core/money/money.dart';
import 'package:bipa/features/markets/data/drift_market_repository.dart';
import 'package:bipa/features/markets/domain/market.dart';
import 'package:bipa/features/prices/data/drift_price_repository.dart';
import 'package:bipa/features/prices/domain/price_observation.dart';
import 'package:bipa/features/prices/domain/price_source.dart';
import 'package:bipa/features/products/data/drift_product_repository.dart';
import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/shopping_list/data/drift_aisle_order_repository.dart';
import 'package:bipa/features/shopping_list/data/drift_shopping_trip_repository.dart';
import 'package:bipa/features/shopping_list/domain/aisle_order.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DriftMarketRepository markets;
  final now = DateTime(2026, 10, 28);

  setUp(() async {
    db = createTestDatabase();
    markets = DriftMarketRepository(db);
    await markets.save(Market(id: 'vila', name: 'Vila Nova', createdAt: now, updatedAt: now));
  });

  tearDown(() => db.close());

  test('apagar o mercado leva os preços e a ordem das seções; as compras ficam sem mercado', () async {
    await DriftProductRepository(
      db,
    ).save(Product(id: 'arroz', name: 'Arroz', unit: MeasureUnit.kilogram, createdAt: now, updatedAt: now));
    await DriftPriceRepository(db).add(
      PriceObservation(
        id: 'preco',
        productId: 'arroz',
        marketId: 'vila',
        price: const Money.cents(2790),
        source: PriceSource.priceTag,
        observedAt: now,
        createdAt: now,
      ),
    );
    await DriftAisleOrderRepository(
      db,
    ).save('vila', const AisleOrder({Aisle.dairy: LearnedAisle(position: 0.2, samples: 1)}));
    final trips = DriftShoppingTripRepository(db, ids: SequentialIdGenerator(), clock: () => now);
    final trip = await trips.start(marketId: 'vila');

    await markets.delete('vila');

    expect(await markets.findById('vila'), isNull);
    expect(await db.select(db.priceObservations).get(), isEmpty);
    expect(await db.select(db.marketAisles).get(), isEmpty);
    expect((await trips.findActive())?.id, trip.id);
    expect((await trips.findActive())?.marketId, isNull);
  });
}
