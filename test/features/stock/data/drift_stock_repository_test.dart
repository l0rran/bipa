import 'package:bipa/core/database/app_database.dart';
import 'package:bipa/features/products/data/drift_product_repository.dart';
import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/stock/data/drift_stock_repository.dart';
import 'package:bipa/features/stock/domain/stock_location.dart';
import 'package:bipa/features/stock/domain/stock_movement_reason.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DriftStockRepository repository;
  final now = DateTime(2026, 10, 27);

  setUp(() async {
    db = createTestDatabase();
    repository = DriftStockRepository(db, ids: SequentialIdGenerator(), clock: () => now);
    await DriftProductRepository(db).save(
      Product(id: 'arroz', name: 'Arroz', unit: MeasureUnit.kilogram, createdAt: now, updatedAt: now),
    );
  });

  tearDown(() => db.close());

  Future<int> movementCount() async => (await db.select(db.stockMovements).get()).length;

  test('adjust cria o item na primeira entrada', () async {
    await repository.adjust(productId: 'arroz', delta: 2, reason: StockMovementReason.purchase);

    final item = await repository.findByProduct('arroz');
    expect(item?.quantity, 2);
    expect(item?.location, StockLocation.pantry);
    expect(await movementCount(), 1);
  });

  test('adjust soma e subtrai sem deixar o estoque negativo', () async {
    await repository.adjust(productId: 'arroz', delta: 2, reason: StockMovementReason.purchase);
    await repository.adjust(productId: 'arroz', delta: -5, reason: StockMovementReason.consumption);

    final item = await repository.findByProduct('arroz');
    expect(item?.quantity, 0);

    final movements = await db.select(db.stockMovements).get();
    expect(movements.map((m) => m.delta), [2, -2]);
  });

  test('ajuste sem efeito não gera movimento', () async {
    await repository.adjust(productId: 'arroz', delta: -1, reason: StockMovementReason.consumption);

    expect((await repository.findByProduct('arroz'))?.quantity, 0);
    expect(await movementCount(), 0);
  });

  test('configura mínimo e local, mesmo antes da primeira entrada', () async {
    await repository.setMinimumQuantity('arroz', 1);
    await repository.setLocation('arroz', StockLocation.freezer);

    final item = await repository.findByProduct('arroz');
    expect(item?.minimumQuantity, 1);
    expect(item?.location, StockLocation.freezer);
    expect(item?.isLow, isTrue);
  });

  test('watchAll traz o produto junto com o item', () async {
    await repository.adjust(productId: 'arroz', delta: 1, reason: StockMovementReason.purchase);

    final entries = await repository.watchAll().first;
    expect(entries.single.product.name, 'Arroz');
    expect(entries.single.item.quantity, 1);
  });
}
