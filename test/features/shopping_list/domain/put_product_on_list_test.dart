import 'package:bipa/core/database/app_database.dart';
import 'package:bipa/features/products/data/drift_product_repository.dart';
import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/shopping_list/data/drift_shopping_list_repository.dart';
import 'package:bipa/features/shopping_list/domain/put_product_on_list.dart';
import 'package:bipa/features/stock/data/drift_stock_repository.dart';
import 'package:bipa/features/stock/domain/stock_movement_reason.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DriftShoppingListRepository list;
  late DriftStockRepository stock;
  late PutProductOnList put;
  final now = DateTime(2026, 10, 28, 9);
  final leite = Product(id: 'leite', name: 'Leite', unit: MeasureUnit.liter, createdAt: now, updatedAt: now);

  setUp(() async {
    db = createTestDatabase();
    list = DriftShoppingListRepository(db, ids: SequentialIdGenerator(), clock: () => now);
    stock = DriftStockRepository(db, ids: SequentialIdGenerator(), clock: () => now);
    put = PutProductOnList(list: list, stock: stock);
    await DriftProductRepository(db).save(leite);
  });

  tearDown(() => db.close());

  test('entra com o que falta para o "ter sempre"', () async {
    await stock.adjust(productId: 'leite', delta: 1, reason: StockMovementReason.purchase);
    await stock.setTargetQuantity('leite', 4);

    await put(leite);

    expect((await list.watchAll().first).single.item.quantity, 3);
  });

  test('sem estoque nem "ter sempre", entra com 1', () async {
    await put(leite);

    expect((await list.watchAll().first).single.item.quantity, 1);
  });
}
