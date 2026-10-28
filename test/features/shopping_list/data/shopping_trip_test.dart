import 'package:bipa/core/catalog/product_kind.dart';
import 'package:bipa/core/database/app_database.dart';
import 'package:bipa/core/database/drift_unit_of_work.dart';
import 'package:bipa/core/money/money.dart';
import 'package:bipa/features/markets/data/drift_market_repository.dart';
import 'package:bipa/features/markets/domain/market.dart';
import 'package:bipa/features/prices/data/drift_price_repository.dart';
import 'package:bipa/features/prices/domain/price_observation.dart';
import 'package:bipa/features/prices/domain/price_source.dart';
import 'package:bipa/features/products/data/drift_product_repository.dart';
import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/products/domain/product_package.dart';
import 'package:bipa/features/shopping_list/data/drift_aisle_order_repository.dart';
import 'package:bipa/features/shopping_list/data/drift_cart_repository.dart';
import 'package:bipa/features/shopping_list/data/drift_shopping_list_repository.dart';
import 'package:bipa/features/shopping_list/data/drift_shopping_trip_repository.dart';
import 'package:bipa/features/shopping_list/domain/aisle_order.dart';
import 'package:bipa/features/shopping_list/domain/cart_item.dart';
import 'package:bipa/features/shopping_list/domain/finish_shopping_trip.dart';
import 'package:bipa/features/shopping_list/domain/review_shopping_trip.dart';
import 'package:bipa/features/shopping_list/domain/shopping_list_item.dart';
import 'package:bipa/features/shopping_list/domain/shopping_trip.dart';
import 'package:bipa/features/stock/data/drift_stock_repository.dart';
import 'package:bipa/features/stock/domain/stock_movement_reason.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DriftShoppingTripRepository trips;
  late DriftShoppingListRepository list;
  late DriftStockRepository stock;
  late DriftCartRepository cart;
  late FinishShoppingTrip finish;
  late DriftAisleOrderRepository aisles;
  late DateTime now;

  setUp(() async {
    now = DateTime(2026, 10, 28, 9);
    db = createTestDatabase();
    final ids = SequentialIdGenerator();
    DateTime clock() => now;
    trips = DriftShoppingTripRepository(db, ids: ids, clock: clock);
    list = DriftShoppingListRepository(db, ids: ids, clock: clock);
    stock = DriftStockRepository(db, ids: ids, clock: clock);
    cart = DriftCartRepository(db, ids: ids, clock: clock);
    aisles = DriftAisleOrderRepository(db);
    finish = FinishShoppingTrip(
      trips: trips,
      list: list,
      cart: cart,
      stock: stock,
      aisles: aisles,
      work: DriftUnitOfWork(db),
    );

    final products = DriftProductRepository(db);
    for (final (id, name) in [('cafe', 'Café'), ('arroz', 'Arroz')]) {
      await products.save(Product(id: id, name: name, unit: MeasureUnit.unit, createdAt: now, updatedAt: now));
    }
  });

  tearDown(() => db.close());

  test('começar duas vezes devolve a mesma compra', () async {
    final first = await trips.start();
    final second = await trips.start(marketId: 'outro');

    expect(second, first);
    expect(await trips.watchActive().first, first);
  });

  test('registrar o preço marca o produto da lista como comprado', () async {
    await list.addProduct(productId: 'cafe', name: 'Café');

    await list.checkProduct('cafe');
    await list.checkProduct('arroz');

    final entries = await list.watchAll().first;
    expect(entries.single.item.isChecked, isTrue);
  });

  test('terminar põe o comprado no estoque, tira da lista e fecha a compra; desfazer volta tudo', () async {
    final trip = await trips.start();
    await list.addProduct(productId: 'cafe', name: 'Café');
    now = now.add(const Duration(minutes: 1));
    await list.addProduct(productId: 'arroz', name: 'Arroz');
    await list.addCustom('Pão');
    await list.checkProduct('cafe');
    final pao = (await list.watchAll().first).firstWhere((e) => e.name == 'Pão');
    await list.setChecked(pao.item.id, checked: true);

    final finished = (await finish(trip.id))!;

    expect(finished.stocked, {'cafe': 1});
    expect((await stock.findByProduct('cafe'))?.quantity, 1);
    expect((await list.watchAll().first).map((e) => e.name), ['Arroz']);
    expect(await trips.watchActive().first, isNull);

    await finish.undo(finished);

    expect((await stock.findByProduct('cafe'))?.quantity, 0);
    expect(await list.watchAll().first, hasLength(3));
    expect((await trips.watchActive().first)?.id, trip.id);
  });

  test('o marcado à mão entra no estoque com a quantidade da lista', () async {
    final trip = await trips.start();
    await list.addProduct(productId: 'cafe', name: 'Café', quantity: 3);
    await list.checkProduct('cafe');

    final finished = (await finish(trip.id))!;

    expect(finished.stocked, {'cafe': 3});
    expect((await stock.findByProduct('cafe'))?.quantity, 3);
  });

  test('a revisão do fim mostra o total, o que faltou e a economia contra outro mercado', () async {
    final markets = DriftMarketRepository(db);
    for (final (id, name) in [('vila', 'Vila'), ('centro', 'Centro')]) {
      await markets.save(Market(id: id, name: name, createdAt: now, updatedAt: now));
    }
    final prices = DriftPriceRepository(db);
    for (final (id, market, cents) in [('p1', 'vila', 1899), ('p2', 'centro', 2099)]) {
      await prices.add(
        PriceObservation(
          id: id,
          productId: 'cafe',
          marketId: market,
          price: Money.cents(cents),
          source: PriceSource.priceTag,
          observedAt: now,
          createdAt: now,
        ),
      );
    }
    final trip = await trips.start(marketId: 'vila');
    await cart.addProduct(trip.id, 'cafe', price: const Money.cents(1899));
    await list.addProduct(productId: 'arroz', name: 'Arroz');
    final review = ReviewShoppingTrip(
      trips: trips,
      list: list,
      cart: cart,
      prices: prices,
      products: DriftProductRepository(db),
    );

    final result = (await review(trip.id))!;

    expect(result.spent, const Money.cents(1899));
    expect(result.packages, 1);
    expect(result.missing, ['Arroz']);
    expect(result.savings, (marketName: 'Centro', amount: const Money.cents(200)));
    expect(await review('outra'), isNull);
  });

  test('cancelar a compra descarta o carrinho e não mexe no estoque nem na lista', () async {
    final trip = await trips.start();
    await list.addProduct(productId: 'cafe', name: 'Café');
    await cart.addProduct(trip.id, 'cafe');
    await list.checkProduct('cafe');

    await trips.cancel(trip.id);

    expect(await trips.watchActive().first, isNull);
    expect(await cart.watchTrip(trip.id).first, isEmpty);
    expect(await stock.findByProduct('cafe'), isNull);
    expect((await list.watchAll().first).single.item.isChecked, isTrue);
  });

  test('um segundo "Terminei" não mexe no estoque de novo', () async {
    final trip = await trips.start();
    await list.addProduct(productId: 'cafe', name: 'Café');
    await list.checkProduct('cafe');

    await finish(trip.id);
    expect(await finish(trip.id), isNull);

    expect((await stock.findByProduct('cafe'))?.quantity, 1);
  });

  test('desfazer não reabre a compra antiga se outra já começou', () async {
    final old = await trips.start();
    final finished = (await finish(old.id))!;
    now = now.add(const Duration(minutes: 5));
    final current = await trips.start();

    await finish.undo(finished);

    expect((await trips.watchActive().first)?.id, current.id);
  });

  test('o carrinho soma unidades, traz o último bipado para o topo e guarda o preço', () async {
    final trip = await trips.start();
    await cart.addProduct(trip.id, 'cafe', price: const Money.cents(1899));
    now = now.add(const Duration(minutes: 1));
    await cart.addProduct(trip.id, 'arroz');
    now = now.add(const Duration(minutes: 1));
    await cart.addProduct(trip.id, 'cafe');

    final entries = await cart.watchTrip(trip.id).first;

    expect(entries.map((e) => (e.product.id, e.item.quantity, e.item.price)), [
      ('cafe', 2, const Money.cents(1899)),
      ('arroz', 1, null),
    ]);
  });

  test('o preço da etiqueta entra no carrinho sem somar unidade', () async {
    final trip = await trips.start();
    await cart.setPriceForProduct(trip.id, 'cafe', const Money.cents(1799));
    await cart.addProduct(trip.id, 'cafe');
    await cart.setPriceForProduct(trip.id, 'cafe', const Money.cents(1699));

    final entries = await cart.watchTrip(trip.id).first;

    expect(entries.map((e) => (e.product.id, e.item.quantity, e.item.price)), [
      ('cafe', 2, const Money.cents(1699)),
    ]);
  });

  test('desmarcar na lista deixa o item do carrinho de fora', () async {
    final trip = await trips.start();
    await cart.addProduct(trip.id, 'cafe');

    await cart.setTakeForProduct(trip.id, 'cafe', take: false);
    await cart.setTakeForProduct(trip.id, 'arroz', take: false);

    final entries = await cart.watchTrip(trip.id).first;
    expect(entries.map((e) => (e.product.id, e.item.take)), [('cafe', false)]);
  });

  test('terminar leva ao estoque o que vai no carrinho, na quantidade bipada', () async {
    final trip = await trips.start();
    await list.addProduct(productId: 'cafe', name: 'Café');
    await list.addProduct(productId: 'arroz', name: 'Arroz');
    await cart.addProduct(trip.id, 'cafe');
    await cart.addProduct(trip.id, 'cafe');
    await cart.addProduct(trip.id, 'arroz');
    final arroz = (await cart.watchTrip(trip.id).first).firstWhere((e) => e.product.id == 'arroz');
    await cart.setTake(arroz.item.id, take: false);
    await list.checkProduct('cafe');
    await list.checkProduct('arroz');

    final finished = (await finish(trip.id))!;

    expect(finished.stocked, {'cafe': 2});
    expect((await stock.findByProduct('cafe'))?.quantity, 2);
    expect(await stock.findByProduct('arroz'), isNull);
  });

  test('embalagens diferentes do mesmo produto são itens diferentes e somam no estoque dele', () async {
    final products = DriftProductRepository(db);
    for (final (id, brand, size) in [('tio-joao', 'Tio João', 5.0), ('camil', 'Camil', 10.0)]) {
      await products.savePackage(
        ProductPackage(
          id: id,
          productId: 'arroz',
          brand: brand,
          size: size,
          unit: MeasureUnit.kilogram,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
    final trip = await trips.start();
    await cart.addProduct(trip.id, 'arroz', packageId: 'tio-joao', price: const Money.cents(2790));
    now = now.add(const Duration(minutes: 1));
    await cart.addProduct(trip.id, 'arroz', packageId: 'camil', price: const Money.cents(4990));
    await cart.addProduct(trip.id, 'arroz', packageId: 'camil');

    final entries = await cart.watchTrip(trip.id).first;
    expect(entries.map((e) => (e.name, e.item.quantity)), [('Arroz Camil 10 kg', 2), ('Arroz Tio João 5 kg', 1)]);

    final finished = (await finish(trip.id))!;
    expect(finished.stocked, {'arroz': 3});
    final lots = await stock.watchLots('arroz').first;
    expect(lots.map((lot) => (lot.packageId, lot.quantity)), unorderedEquals([('tio-joao', 1.0), ('camil', 2.0)]));

    await finish.undo(finished);

    expect((await stock.findByProduct('arroz'))?.quantity, 0);
    expect(await stock.watchLots('arroz').first, isEmpty);
  });

  test('desfazer o "Terminei" tira o que entrou, não o que já estava em casa', () async {
    final products = DriftProductRepository(db);
    for (final (id, day) in [('tio-joao', 1), ('camil', 2)]) {
      await products.savePackage(
        ProductPackage(
          id: id,
          productId: 'arroz',
          size: 5,
          unit: MeasureUnit.kilogram,
          createdAt: DateTime(2026, 9, day),
          updatedAt: DateTime(2026, 9, day),
        ),
      );
    }
    await stock.adjust(productId: 'arroz', packageId: 'tio-joao', delta: 1, reason: StockMovementReason.purchase);
    final trip = await trips.start();
    // Marcado à mão na lista: entra sem embalagem informada, na mais nova.
    await list.addProduct(productId: 'arroz', name: 'Arroz');
    await list.checkProduct('arroz');

    final finished = (await finish(trip.id))!;
    await finish.undo(finished);

    final lots = await stock.watchLots('arroz').first;
    expect(lots.map((lot) => (lot.packageId, lot.quantity)), [('tio-joao', 1.0)]);
  });

  test('o preço do histórico é estimado e não apaga o lido na etiqueta', () async {
    final trip = await trips.start();
    await cart.addProduct(trip.id, 'cafe', price: const Money.cents(1899), estimated: true);
    var item = (await cart.watchTrip(trip.id).first).single.item;
    expect((item.price?.cents, item.priceEstimated), (1899, true));

    await cart.setPrice(item.id, const Money.cents(1799));
    // Bipar de novo com o preço do histórico não troca o lido.
    await cart.addProduct(trip.id, 'cafe', price: const Money.cents(1899), estimated: true);

    item = (await cart.watchTrip(trip.id).first).single.item;
    expect((item.price?.cents, item.priceEstimated, item.quantity), (1799, false, 2));

    final summary = ShoppingTripSummary.of(const [], await cart.watchTrip(trip.id).first);
    expect((summary.spent?.cents, summary.estimated), (3598, false));

    await cart.setQuantity(item.id, 0);
    expect((await cart.watchTrip(trip.id).first).single.item.quantity, 1);
  });

  test('o resumo da compra soma só o que vai levar, com os preços conhecidos', () async {
    ShoppingListEntry entry(String id, {bool checked = false}) => ShoppingListEntry(
      item: ShoppingListItem(id: id, productId: id, name: id, addedAt: now, checkedAt: checked ? now : null),
    );
    CartEntry inCart(String id, {Money? price, int quantity = 1, bool take = true}) => CartEntry(
      item: CartItem(id: id, tripId: 't', productId: id, addedAt: now, price: price, quantity: quantity, take: take),
      product: Product(id: id, name: id, unit: MeasureUnit.unit, createdAt: now, updatedAt: now),
    );

    final summary = ShoppingTripSummary.of(
      [entry('cafe', checked: true), entry('arroz'), entry('leite', checked: true)],
      [
        inCart('cafe', price: const Money.cents(1799), quantity: 2),
        inCart('arroz', price: const Money.cents(2790), take: false),
        inCart('leite'),
      ],
    );

    // O leite vai sem preço: fica fora do total e é contado à parte.
    expect(summary, const ShoppingTripSummary(done: 2, total: 3, spent: Money.cents(3598), unpriced: 1));
    expect(ShoppingTripSummary.of(const [], const []).spent, isNull);
  });

  test('no mercado da compra, o "Terminei" aprende a ordem das seções; desfazer esquece', () async {
    await DriftMarketRepository(db).save(Market(id: 'vila', name: 'Vila Nova', createdAt: now, updatedAt: now));
    final trip = await trips.start(marketId: 'vila');
    await list.addCustom('Detergente');
    await list.addCustom('Tomate');
    final items = await list.watchAll().first;
    // Limpeza primeiro, hortifrúti depois: o contrário da ordem genérica.
    for (final name in ['Detergente', 'Tomate']) {
      now = now.add(const Duration(minutes: 5));
      await list.setChecked(items.firstWhere((e) => e.name == name).item.id, checked: true);
    }

    final finished = (await finish(trip.id))!;

    final learned = await aisles.find('vila');
    expect(learned.sort([Aisle.produce, Aisle.cleaning]), [Aisle.cleaning, Aisle.produce]);

    await finish.undo(finished);

    expect(await aisles.find('vila'), AisleOrder.empty);
  });

  test('o último mercado é o da compra mais recente que teve mercado', () async {
    final markets = DriftMarketRepository(db);
    for (final id in ['vila', 'centro']) {
      await markets.save(Market(id: id, name: id, createdAt: now, updatedAt: now));
    }
    expect(await trips.watchLastMarketId().first, isNull);

    final vila = await trips.start(marketId: 'vila');
    await trips.finish(vila.id);
    now = now.add(const Duration(days: 1));
    final centro = await trips.start(marketId: 'centro');
    await trips.finish(centro.id);
    now = now.add(const Duration(days: 1));
    // Uma compra sem mercado detectado não muda o último mercado.
    await trips.start();

    expect(await trips.watchLastMarketId().first, 'centro');
  });
}
