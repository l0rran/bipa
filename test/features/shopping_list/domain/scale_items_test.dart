import 'package:bipa/core/database/app_database.dart';
import 'package:bipa/core/money/money.dart';
import 'package:bipa/features/markets/data/drift_market_repository.dart';
import 'package:bipa/features/markets/domain/market.dart';
import 'package:bipa/features/products/data/drift_product_repository.dart';
import 'package:bipa/features/products/domain/create_product_by_weight.dart';
import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:bipa/features/products/domain/scale_label.dart';
import 'package:bipa/features/shopping_list/data/drift_cart_repository.dart';
import 'package:bipa/features/shopping_list/data/drift_scale_item_repository.dart';
import 'package:bipa/features/shopping_list/data/drift_shopping_list_repository.dart';
import 'package:bipa/features/shopping_list/data/drift_shopping_trip_repository.dart';
import 'package:bipa/features/shopping_list/domain/match_list_to_cart.dart';
import 'package:bipa/features/shopping_list/domain/scale_items.dart';
import 'package:bipa/features/shopping_list/domain/shopping_trip.dart';
import 'package:bipa/features/shopping_list/domain/trip_review.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late ScaleItems scale;
  late DriftCartRepository cart;
  late DriftShoppingTripRepository trips;
  late DriftShoppingListRepository list;
  late CreateProductByWeight createProduct;
  final now = DateTime(2026, 10, 28, 10);
  final tomate = ScaleLabel.tryParse('2001230008437')!;
  final outroSaco = ScaleLabel.tryParse('2001230012991')!;

  setUp(() async {
    db = createTestDatabase();
    final ids = SequentialIdGenerator();
    cart = DriftCartRepository(db, ids: ids, clock: () => now);
    trips = DriftShoppingTripRepository(db, ids: ids, clock: () => now);
    list = DriftShoppingListRepository(db, ids: ids, clock: () => now);
    createProduct = CreateProductByWeight(products: DriftProductRepository(db), ids: ids, clock: () => now);
    scale = ScaleItems(
      scale: DriftScaleItemRepository(db),
      products: DriftProductRepository(db),
      cart: cart,
      createProduct: createProduct,
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

  test('a pesagem troca o preço de uma linha que não é de pesagens', () async {
    final trip = await trips.start(marketId: 'vila');
    final product = await scale.remember('vila', tomate, newName: 'Tomate');
    // O preço do histórico, estimado, numa linha de duas unidades.
    await cart.addProduct(trip.id, product.id, price: const Money.cents(599), estimated: true);
    final line = (await cart.watchTrip(trip.id).first).single.item;
    await cart.setQuantity(line.id, 2);

    await scale.addToCart(trip.id, product, tomate);

    final entry = (await cart.watchTrip(trip.id).first).single.item;
    expect((entry.quantity, entry.price, entry.priceEstimated), (1, const Money.cents(843), false));
  });

  test('trocar o produto de uma pesagem regrava o código e leva a linha para o novo', () async {
    final trip = await trips.start(marketId: 'vila');
    final nanica = await scale.remember('vila', tomate, newName: 'Banana nanica');
    await scale.addToCart(trip.id, nanica, tomate);
    final prata = await scale.remember(null, tomate, newName: 'Banana prata');

    final line = (await cart.watchTrip(trip.id).first).single.item;
    await scale.swapProduct(trip.id, 'vila', line, prata);

    expect((await scale.productFor('vila', outroSaco))?.id, prata.id);
    final entry = (await cart.watchTrip(trip.id).first).single.item;
    expect((entry.productId, entry.price), (prata.id, const Money.cents(843)));
  });

  test('trocar para um produto que já tem linha conta como mais uma pesagem nela', () async {
    final trip = await trips.start(marketId: 'vila');
    final nanica = await scale.remember('vila', tomate, newName: 'Banana nanica');
    await scale.addToCart(trip.id, nanica, tomate);
    final prata = await scale.remember(null, tomate, newName: 'Banana prata');
    // A prata já estava com o preço do histórico, estimado, em duas unidades.
    await cart.addProduct(trip.id, prata.id, price: const Money.cents(599), estimated: true);
    final estimated = (await cart.watchTrip(trip.id).first).firstWhere((e) => e.item.productId == prata.id).item;
    await cart.setQuantity(estimated.id, 2);

    final line = (await cart.watchTrip(trip.id).first).firstWhere((e) => e.item.productId == nanica.id).item;
    await scale.swapProduct(trip.id, 'vila', line, prata);

    final entry = (await cart.watchTrip(trip.id).first).single.item;
    expect(
      (entry.productId, entry.quantity, entry.price, entry.priceEstimated),
      (prata.id, 1, const Money.cents(843), false),
    );
  });

  group('granel escolhido pela etiqueta por quilo (D3)', () {
    test('entra uma linha sem embalagem e sem preço, e escolher de novo não duplica', () async {
      final trip = await trips.start(marketId: 'vila');
      final product = await createProduct('Tomate italiano');

      await scale.addGranel(trip.id, product.id);
      await scale.addGranel(trip.id, product.id);

      final entry = (await cart.watchTrip(trip.id).first).single.item;
      expect(
        (entry.productId, entry.packageId, entry.quantity, entry.price, entry.priceEstimated, entry.take),
        (product.id, null, 1, null, false, true),
      );
    });

    test('não mexe numa linha que a pesagem já firmou', () async {
      final trip = await trips.start(marketId: 'vila');
      final product = await scale.remember('vila', tomate, newName: 'Tomate');
      await scale.addToCart(trip.id, product, tomate);

      await scale.addGranel(trip.id, product.id);

      final entry = (await cart.watchTrip(trip.id).first).single.item;
      expect((entry.quantity, entry.price, entry.priceEstimated), (1, const Money.cents(843), false));
    });

    test('a etiqueta da balança firma o valor na mesma linha', () async {
      final trip = await trips.start(marketId: 'vila');
      final product = await scale.remember('vila', tomate, newName: 'Tomate');
      await scale.addGranel(trip.id, product.id);

      await scale.addToCart(trip.id, product, tomate);

      final entry = (await cart.watchTrip(trip.id).first).single.item;
      expect(
        (entry.packageId, entry.quantity, entry.price, entry.priceEstimated),
        (null, 1, const Money.cents(843), false),
      );
      // A segunda pesagem soma na mesma linha, como sempre.
      await scale.addToCart(trip.id, product, outroSaco);
      expect((await cart.watchTrip(trip.id).first).single.item.price, const Money.cents(843 + 1299));
    });

    test('conta como sem preço nos totais, sem inventar valor', () async {
      final trip = await trips.start(marketId: 'vila');
      final cafe = await createProduct('Café');
      final tomateItaliano = await createProduct('Tomate italiano');
      await cart.addProduct(trip.id, cafe.id, price: const Money.cents(1899));
      await scale.addGranel(trip.id, tomateItaliano.id);
      final entries = await list.watchAll().first;
      final inCart = await cart.watchTrip(trip.id).first;

      final summary = ShoppingTripSummary.of(entries, inCart, since: trip.startedAt);
      final review = TripReview.of(entries: entries, cart: inCart, since: trip.startedAt);

      expect((summary.spent, summary.estimated, summary.unpriced), (const Money.cents(1899), false, 1));
      expect(
        (review.spent, review.estimated, review.unpriced, review.packages),
        (const Money.cents(1899), false, 1, 2),
      );
    });

    test('marca a lista como o bipe: "1 de 3" continua faltando', () async {
      final trip = await trips.start(marketId: 'vila');
      final tomateItaliano = await createProduct('Tomate italiano');
      final batata = await createProduct('Batata');
      await list.addProduct(productId: tomateItaliano.id, name: 'Tomate italiano', quantity: 3);
      await list.addProduct(productId: batata.id, name: 'Batata');
      final match = MatchListToCart(list: list, cart: cart);

      for (final product in [tomateItaliano, batata]) {
        await scale.addGranel(trip.id, product.id);
        await match(trip.id, product.id, CartListChange.added);
      }

      final checked = {for (final entry in await list.watchAll().first) entry.item.productId: entry.item.isChecked};
      expect(checked, {tomateItaliano.id: false, batata.id: true});
    });
  });
}
