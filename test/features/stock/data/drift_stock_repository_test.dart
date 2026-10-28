import 'package:bipa/core/database/app_database.dart';
import 'package:bipa/features/products/data/drift_product_repository.dart';
import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/products/domain/product_package.dart';
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
    await repository.setTargetQuantity('arroz', 1);
    await repository.setLocation('arroz', StockLocation.freezer);

    final item = await repository.findByProduct('arroz');
    expect(item?.targetQuantity, 1);
    expect(item?.location, StockLocation.freezer);
    expect(item?.isLow, isTrue);
  });

  test('watchAll traz o produto junto com o item', () async {
    await repository.adjust(productId: 'arroz', delta: 1, reason: StockMovementReason.purchase);

    final entries = await repository.watchAll().first;
    expect(entries.single.product.name, 'Arroz');
    expect(entries.single.item.quantity, 1);
  });

  group('embalagens em casa', () {
    late DriftStockRepository stock;
    late DateTime clock;

    setUp(() async {
      clock = DateTime(2026, 10, 1);
      stock = DriftStockRepository(db, ids: SequentialIdGenerator(), clock: () => clock);
      final products = DriftProductRepository(db);
      for (final (id, size, day) in [('tio-joao', 5.0, 1), ('camil', 10.0, 2)]) {
        await products.savePackage(
          ProductPackage(
            id: id,
            productId: 'arroz',
            size: size,
            unit: MeasureUnit.kilogram,
            createdAt: DateTime(2026, 9, day),
            updatedAt: DateTime(2026, 9, day),
          ),
        );
      }
    });

    Future<Map<String, double>> counts() async => {
      for (final count in await stock.watchPackages('arroz').first) count.package.id: count.quantity,
    };

    test('a compra entra na embalagem informada e, sem ela, na mais nova', () async {
      await stock.adjust(productId: 'arroz', packageId: 'tio-joao', delta: 1, reason: StockMovementReason.purchase);
      clock = clock.add(const Duration(days: 1));
      await stock.adjust(productId: 'arroz', delta: 1, reason: StockMovementReason.purchase);

      expect(await counts(), {'tio-joao': 1, 'camil': 1});
      expect((await stock.findByProduct('arroz'))?.quantity, 2);
    });

    test('"usei um" tira a embalagem que está em casa há mais tempo', () async {
      await stock.adjust(productId: 'arroz', packageId: 'camil', delta: 1, reason: StockMovementReason.purchase);
      clock = clock.add(const Duration(days: 1));
      await stock.adjust(productId: 'arroz', packageId: 'tio-joao', delta: 1, reason: StockMovementReason.purchase);

      await stock.adjust(productId: 'arroz', delta: -1, reason: StockMovementReason.consumption);

      expect(await counts(), {'tio-joao': 1});
    });

    test('o desfazer de uma compra tira a embalagem que entrou', () async {
      await stock.adjust(productId: 'arroz', packageId: 'tio-joao', delta: 1, reason: StockMovementReason.purchase);
      clock = clock.add(const Duration(days: 1));
      await stock.adjust(productId: 'arroz', packageId: 'camil', delta: 1, reason: StockMovementReason.purchase);

      await stock.adjust(productId: 'arroz', packageId: 'camil', delta: -1, reason: StockMovementReason.adjustment);

      expect(await counts(), {'tio-joao': 1});
    });
  });
}
