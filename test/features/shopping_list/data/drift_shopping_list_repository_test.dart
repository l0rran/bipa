import 'package:bipa/core/database/app_database.dart';
import 'package:bipa/features/products/data/drift_product_repository.dart';
import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/shopping_list/data/drift_shopping_list_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DriftShoppingListRepository list;
  late DateTime now;

  /// O banco guarda as datas em segundos: cada item entra um minuto depois.
  void tick() => now = now.add(const Duration(minutes: 1));

  setUp(() async {
    now = DateTime(2026, 10, 28, 9);
    db = createTestDatabase();
    list = DriftShoppingListRepository(db, ids: SequentialIdGenerator(), clock: () => now);
    final created = DateTime(2026);
    await DriftProductRepository(db).save(
      Product(id: 'cafe', name: 'Café Pilão 500 g', unit: MeasureUnit.gram, createdAt: created, updatedAt: created),
    );
  });

  tearDown(() => db.close());

  test('produto e item escrito à mão, na ordem em que entraram', () async {
    await list.addProduct(productId: 'cafe', name: 'Café');
    tick();
    await list.addCustom('  Pão  ');

    final entries = await list.watchAll().first;

    expect(entries.map((e) => e.name), ['Café Pilão 500 g', 'Pão']);
    expect(entries.first.product?.id, 'cafe');
    expect(entries.last.product, isNull);
  });

  test('pôr o mesmo produto de novo não duplica e volta a faltar', () async {
    await list.addProduct(productId: 'cafe', name: 'Café');
    final id = (await list.watchAll().first).single.item.id;
    await list.setChecked(id, checked: true);

    await list.addProduct(productId: 'cafe', name: 'Café');

    final entries = await list.watchAll().first;
    expect(entries, hasLength(1));
    expect(entries.single.item.isChecked, isFalse);
  });

  test('guarda a quantidade, que volta com o desfazer e nunca fica abaixo de 1', () async {
    await list.addProduct(productId: 'cafe', name: 'Café', quantity: 3);
    final item = (await list.watchAll().first).single.item;
    expect(item.quantity, 3);

    // Pôr de novo o que ainda falta não muda a quantidade.
    await list.addProduct(productId: 'cafe', name: 'Café');
    expect((await list.watchAll().first).single.item.quantity, 3);

    await list.setQuantity(item.id, 0);
    expect((await list.watchAll().first).single.item.quantity, 1);

    await list.remove(item.id);
    await list.restore(item);
    expect((await list.watchAll().first).single.item.quantity, 3);
  });

  test('comprado e posto de novo, vale a quantidade nova', () async {
    await list.addProduct(productId: 'cafe', name: 'Café', quantity: 3);
    final id = (await list.watchAll().first).single.item.id;
    await list.setChecked(id, checked: true);

    await list.addProduct(productId: 'cafe', name: 'Café', quantity: 2);

    final item = (await list.watchAll().first).single.item;
    expect((item.isChecked, item.quantity), (false, 2));
  });

  test('remove, desfaz e tira os comprados', () async {
    await list.addProduct(productId: 'cafe', name: 'Café');
    tick();
    await list.addCustom('Pão');
    final [cafe, pao] = await list.watchAll().first;

    await list.remove(pao.item.id);
    expect(await list.watchAll().first, [cafe]);

    await list.restore(pao.item);
    expect((await list.watchAll().first).map((e) => e.name), ['Café Pilão 500 g', 'Pão']);

    await list.setChecked(cafe.item.id, checked: true);
    await list.removeChecked();
    expect((await list.watchAll().first).map((e) => e.name), ['Pão']);
  });

  test('escrever de novo o mesmo item não duplica', () async {
    await list.addCustom('Pão');
    await list.addCustom('pão ');

    expect((await list.watchAll().first).map((e) => e.name), ['Pão']);
  });

  test('desfazer não duplica um produto que já voltou à lista', () async {
    await list.addProduct(productId: 'cafe', name: 'Café');
    final removed = (await list.watchAll().first).single.item;
    await list.remove(removed.id);
    await list.addProduct(productId: 'cafe', name: 'Café');

    await list.restore(removed);

    expect(await list.watchAll().first, hasLength(1));
  });

  test('tira um produto pelo id e ignora itens vazios', () async {
    await list.addProduct(productId: 'cafe', name: 'Café');
    await list.addCustom('   ');

    await list.removeProduct('cafe');

    expect(await list.watchAll().first, isEmpty);
  });
}
