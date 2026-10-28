import 'package:bipa/core/database/app_database.dart';
import 'package:bipa/core/money/money.dart';
import 'package:bipa/features/products/data/drift_product_repository.dart';
import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/shopping_list/data/drift_shopping_list_repository.dart';
import 'package:bipa/features/shopping_list/data/drift_shopping_trip_repository.dart';
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
    finish = FinishShoppingTrip(trips: trips, list: list, stock: stock);

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

    expect(finished.stockedProductIds, ['cafe']);
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

  test('o resumo da compra usa o preço pago e marca quando é estimativa', () {
    ShoppingListEntry entry(String id, {bool checked = false, String? productId}) => ShoppingListEntry(
      item: ShoppingListItem(
        id: id,
        productId: productId,
        name: id,
        addedAt: now,
        checkedAt: checked ? now : null,
      ),
    );

    final paidOnly = ShoppingTripSummary.of(
      [entry('cafe', checked: true, productId: 'cafe'), entry('arroz', productId: 'arroz')],
      tripPrices: {'cafe': const Money.cents(1799)},
      referencePrices: {'cafe': const Money.cents(1899), 'arroz': const Money.cents(2790)},
    );
    expect(paidOnly, const ShoppingTripSummary(done: 1, total: 2, spent: Money.cents(1799)));

    final withEstimate = ShoppingTripSummary.of(
      [entry('cafe', checked: true, productId: 'cafe'), entry('pao', checked: true)],
      tripPrices: const {},
      referencePrices: {'cafe': const Money.cents(1899)},
    );
    expect(withEstimate, const ShoppingTripSummary(done: 2, total: 2, spent: Money.cents(1899), estimated: true));
  });
}
