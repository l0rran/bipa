import 'package:bipa/core/database/app_database.dart';
import 'package:bipa/features/products/data/drift_product_repository.dart';
import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/products/domain/product_package.dart';
import 'package:bipa/features/products/domain/product_repository.dart';
import 'package:bipa/features/shopping_list/data/drift_shopping_list_repository.dart';
import 'package:bipa/features/stock/data/drift_stock_repository.dart';
import 'package:bipa/features/stock/domain/stock_movement_reason.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DriftProductRepository repository;
  final now = DateTime(2026, 10, 27);

  setUp(() {
    db = createTestDatabase();
    repository = DriftProductRepository(db);
  });

  tearDown(() => db.close());

  Product product(String id, String name) =>
      Product(id: id, name: name, unit: MeasureUnit.kilogram, createdAt: now, updatedAt: now);

  ProductPackage package(String id, String productId, {String? barcode, String? brand, double? size, int day = 1}) =>
      ProductPackage(
        id: id,
        productId: productId,
        barcode: barcode,
        brand: brand,
        size: size,
        unit: MeasureUnit.kilogram,
        createdAt: DateTime(2026, 10, day),
        updatedAt: DateTime(2026, 10, day),
      );

  test('salva e busca o produto por id e pelo código de uma embalagem', () async {
    final rice = product('arroz', 'Arroz branco');
    await repository.save(rice);
    await repository.savePackage(package('tio-joao', 'arroz', barcode: '7896006711155', brand: 'Tio João', size: 5));

    expect(await repository.findById('arroz'), rice);
    expect(await repository.findByBarcode('7896006711155'), rice);
    expect((await repository.findPackageByBarcode('7896006711155'))?.brand, 'Tio João');
    expect(await repository.findByBarcode('4006381333931'), isNull);
  });

  test('um produto tem várias embalagens, das mais novas para as mais antigas', () async {
    await repository.save(product('arroz', 'Arroz branco'));
    await repository.savePackage(package('tio-joao', 'arroz', brand: 'Tio João', size: 5, day: 1));
    await repository.savePackage(package('camil', 'arroz', brand: 'Camil', size: 10, day: 2));

    final packages = await repository.watchPackages('arroz').first;

    expect(packages.map((p) => p.label), ['Camil · 10 kg', 'Tio João · 5 kg']);
  });

  test('save atualiza um produto existente', () async {
    await repository.save(product('1', 'Cafe'));
    await repository.save(product('1', 'Café torrado'));

    final all = await repository.watchAll().first;
    expect(all.map((p) => p.name), ['Café torrado']);
  });

  test('impede o mesmo código de barras em duas embalagens', () async {
    await repository.save(product('cafe', 'Café'));
    await repository.save(product('outro', 'Outro'));
    await repository.savePackage(package('pilao', 'cafe', barcode: '7891910000197'));

    expect(
      () => repository.savePackage(package('outra', 'outro', barcode: '7891910000197')),
      throwsA(isA<DuplicateBarcodeException>()),
    );
  });

  test('embalagens sem código de barras não conflitam', () async {
    await repository.save(product('frutas', 'Banana'));
    await repository.savePackage(package('cacho', 'frutas'));
    await repository.savePackage(package('penca', 'frutas'));

    expect(await repository.watchPackages('frutas').first, hasLength(2));
  });

  test('watchAll ordena por nome e filtra por nome, marca ou código da embalagem', () async {
    await repository.save(product('1', 'feijão'));
    await repository.save(product('2', 'Arroz'));
    await repository.save(product('3', 'Café'));
    await repository.savePackage(package('a', '1', brand: 'Camil'));
    await repository.savePackage(package('b', '2', brand: 'Camil'));
    await repository.savePackage(package('c', '3', barcode: '7891910000197'));

    final all = await repository.watchAll().first;
    expect(all.map((p) => p.name), ['Arroz', 'Café', 'feijão']);

    final byBrand = await repository.watchAll(query: 'camil').first;
    expect(byBrand.map((p) => p.id), ['2', '1']);

    final byBarcode = await repository.watchAll(query: '7891910000197').first;
    expect(byBarcode.map((p) => p.id), ['3']);

    final byName = await repository.watchAll(query: 'arr').first;
    expect(byName.map((p) => p.id), ['2']);
  });

  test('juntar leva embalagens, preços, estoque e lista para o outro produto', () async {
    await repository.save(product('tio', 'Arroz Tio João'));
    await repository.save(product('arroz', 'Arroz branco'));
    await repository.savePackage(package('tio-5', 'tio', barcode: '7896006711155', brand: 'Tio João', size: 5));
    await repository.savePackage(package('camil-10', 'arroz', brand: 'Camil', size: 10));
    final stock = DriftStockRepository(db, ids: SequentialIdGenerator(), clock: () => now);
    await stock.adjust(productId: 'tio', delta: 1, reason: StockMovementReason.purchase);
    await stock.adjust(productId: 'arroz', delta: 2, reason: StockMovementReason.purchase);
    final list = DriftShoppingListRepository(db, ids: SequentialIdGenerator(), clock: () => now);
    await list.addProduct(productId: 'tio', name: 'Arroz Tio João');
    await list.addProduct(productId: 'arroz', name: 'Arroz branco');

    await repository.merge(fromId: 'tio', intoId: 'arroz');

    expect(await repository.findById('tio'), isNull);
    expect(await repository.findByBarcode('7896006711155'), product('arroz', 'Arroz branco'));
    expect((await repository.watchPackages('arroz').first).map((p) => p.id), unorderedEquals(['tio-5', 'camil-10']));
    expect((await stock.findByProduct('arroz'))?.quantity, 3);
    expect((await stock.watchPackages('arroz').first).map((c) => c.package.id), unorderedEquals(['tio-5', 'camil-10']));
    expect((await list.watchAll().first).map((e) => e.item.productId), ['arroz']);
  });
}
