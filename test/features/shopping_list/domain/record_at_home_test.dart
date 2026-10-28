import 'package:bipa/core/database/app_database.dart';
import 'package:bipa/core/database/drift_unit_of_work.dart';
import 'package:bipa/features/products/data/drift_product_repository.dart';
import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/shopping_list/data/drift_shopping_list_repository.dart';
import 'package:bipa/features/shopping_list/domain/put_product_on_list.dart';
import 'package:bipa/features/shopping_list/domain/record_at_home.dart';
import 'package:bipa/features/shopping_list/domain/shopping_list_item.dart';
import 'package:bipa/features/stock/data/drift_stock_repository.dart';
import 'package:bipa/features/stock/domain/stock_movement_reason.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DriftShoppingListRepository list;
  late DriftStockRepository stock;
  late RecordAtHome record;
  final now = DateTime(2026, 10, 28, 9);
  final leite = Product(id: 'leite', name: 'Leite', unit: MeasureUnit.liter, createdAt: now, updatedAt: now);

  Future<List<ShoppingListItem>> listed() async => [for (final entry in await list.watchAll().first) entry.item];
  Future<double> atHome() async => (await stock.findByProduct('leite'))?.quantity ?? 0;
  Future<void> putAtHome(double quantity, {double? target}) async {
    await stock.adjust(productId: 'leite', delta: quantity, reason: StockMovementReason.purchase);
    if (target != null) await stock.setTargetQuantity('leite', target);
  }

  setUp(() async {
    db = createTestDatabase();
    list = DriftShoppingListRepository(db, ids: SequentialIdGenerator(), clock: () => now);
    stock = DriftStockRepository(db, ids: SequentialIdGenerator(), clock: () => now);
    record = RecordAtHome(
      stock: stock,
      list: list,
      putOnList: PutProductOnList(list: list, stock: stock),
      work: DriftUnitOfWork(db),
    );
    await DriftProductRepository(db).save(leite);
  });

  tearDown(() => db.close());

  group('Comprei', () {
    test('tira da lista o último que faltava, e o desfazer devolve os dois', () async {
      await list.addProduct(productId: 'leite', name: 'Leite');
      final before = (await listed()).single;

      final change = await record.bought(leite);

      expect(change?.list, isA<RemovedFromList>());
      expect(await listed(), isEmpty);
      expect(await atHome(), 1);

      await record.undo(change!);

      expect(await listed(), [before]);
      expect(await atHome(), 0);
    });

    test('faltando mais de um, só diminui o que falta', () async {
      await list.addProduct(productId: 'leite', name: 'Leite', quantity: 3);

      final change = await record.bought(leite);

      expect((await listed()).single.quantity, 2);

      await record.undo(change!);

      expect((await listed()).single.quantity, 3);
    });

    test('fora da lista, ou já marcado como comprado, a lista fica como está', () async {
      expect((await record.bought(leite))?.list, isA<ListUnchanged>());

      await list.addProduct(productId: 'leite', name: 'Leite');
      await list.checkProduct('leite');
      final checked = await listed();

      expect((await record.bought(leite))?.list, isA<ListUnchanged>());
      expect(await listed(), checked);
      expect(await atHome(), 2);
    });
  });

  group('Usei', () {
    test('o último põe na lista, e o desfazer tira dela e devolve o estoque', () async {
      await putAtHome(1);

      final change = await record.used(leite);

      expect(change?.list, isA<AddedToList>());
      expect((await listed()).single.quantity, 1);
      expect(await atHome(), 0);

      await record.undo(change!);

      expect(await listed(), isEmpty);
      expect(await atHome(), 1);
    });

    test('abaixo do "ter sempre", entra com o que falta', () async {
      await putAtHome(3, target: 4);

      await record.used(leite);

      expect((await listed()).single.quantity, 2);
    });

    test('ainda em dia, a lista fica como está', () async {
      await putAtHome(4, target: 2);

      final change = await record.used(leite);

      expect(change?.list, isA<ListUnchanged>());
      expect(await listed(), isEmpty);
      expect(await atHome(), 3);
    });

    test('já na lista, o desfazer não tira o que a pessoa pôs', () async {
      await putAtHome(1);
      await list.addProduct(productId: 'leite', name: 'Leite', quantity: 2);

      final change = await record.used(leite);
      await record.undo(change!);

      expect((await listed()).single.quantity, 2);
      expect(await atHome(), 1);
    });

    test('sem nada em casa, não muda nada', () async {
      expect(await record.used(leite), isNull);
      expect(await listed(), isEmpty);
    });
  });
}
