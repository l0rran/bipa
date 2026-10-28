import 'package:bipa/core/database/app_database.dart';
import 'package:bipa/core/money/money.dart';
import 'package:bipa/features/markets/data/drift_market_repository.dart';
import 'package:bipa/features/markets/domain/market.dart';
import 'package:bipa/features/products/data/drift_product_repository.dart';
import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:bipa/features/products/domain/scale_label.dart';
import 'package:bipa/features/shopping_list/data/drift_cart_repository.dart';
import 'package:bipa/features/shopping_list/data/drift_scale_item_repository.dart';
import 'package:bipa/features/shopping_list/data/drift_shopping_trip_repository.dart';
import 'package:bipa/features/shopping_list/domain/scale_items.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late ScaleItems scale;
  late DriftCartRepository cart;
  late DriftShoppingTripRepository trips;
  final now = DateTime(2026, 10, 28, 10);
  final tomate = ScaleLabel.tryParse('2001230008437')!;
  final outroSaco = ScaleLabel.tryParse('2001230012991')!;

  setUp(() async {
    db = createTestDatabase();
    final ids = SequentialIdGenerator();
    cart = DriftCartRepository(db, ids: ids, clock: () => now);
    trips = DriftShoppingTripRepository(db, ids: ids, clock: () => now);
    scale = ScaleItems(
      scale: DriftScaleItemRepository(db),
      products: DriftProductRepository(db),
      cart: cart,
      ids: ids,
      clock: () => now,
    );
    await DriftMarketRepository(db).save(Market(id: 'vila', name: 'Vila', createdAt: now, updatedAt: now));
  });

  tearDown(() => db.close());

  test('o produto escolhido para o código fica lembrado no mercado', () async {
    expect(await scale.productFor('vila', tomate), isNull);

    final product = await scale.remember('vila', tomate, newName: ' Tomate ');

    expect((product.name, product.unit), ('Tomate', MeasureUnit.kilogram));
    expect((await scale.productFor('vila', outroSaco))?.id, product.id);
    expect(await scale.productFor(null, outroSaco), isNull);
  });

  test('duas pesagens do mesmo produto somam numa linha do carrinho', () async {
    final trip = await trips.start(marketId: 'vila');
    final product = await scale.remember('vila', tomate, newName: 'Tomate');

    await scale.addToCart(trip.id, product, tomate);
    await scale.addToCart(trip.id, product, outroSaco);

    final entry = (await cart.watchTrip(trip.id).first).single;
    expect((entry.item.quantity, entry.item.price, entry.item.packageId), (1, const Money.cents(843 + 1299), null));
  });
}
