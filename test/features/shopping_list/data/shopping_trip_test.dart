import 'package:bipa/core/database/app_database.dart';
import 'package:bipa/core/money/money.dart';
import 'package:bipa/features/products/data/drift_product_repository.dart';
import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/products/domain/product_package.dart';
import 'package:bipa/features/shopping_list/data/drift_cart_repository.dart';
import 'package:bipa/features/shopping_list/data/drift_shopping_list_repository.dart';
import 'package:bipa/features/shopping_list/data/drift_shopping_trip_repository.dart';
import 'package:bipa/features/shopping_list/domain/cart_item.dart';
import 'package:bipa/features/shopping_list/domain/finish_shopping_trip.dart';
import 'package:bipa/features/shopping_list/domain/shopping_list_item.dart';
import 'package:bipa/features/shopping_list/domain/shopping_trip.dart';
import 'package:bipa/features/stock/data/drift_stock_repository.dart';
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
    finish = FinishShoppingTrip(trips: trips, list: list, cart: cart, stock: stock);

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

    expect(summary, const ShoppingTripSummary(done: 2, total: 3, spent: Money.cents(3598)));
    expect(ShoppingTripSummary.of(const [], const []).spent, isNull);
  });
}
