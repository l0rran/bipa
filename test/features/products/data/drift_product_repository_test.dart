import 'package:bipa/core/database/app_database.dart';
import 'package:bipa/features/products/data/drift_product_repository.dart';
import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/products/domain/product_repository.dart';
import 'package:flutter_test/flutter_test.dart';

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

  Product product(String id, String name, {String? barcode, String? brand}) => Product(
    id: id,
    name: name,
    barcode: barcode,
    brand: brand,
    unit: MeasureUnit.gram,
    packageSize: 500,
    createdAt: now,
    updatedAt: now,
  );

  test('salva e busca por id e por código de barras', () async {
    final cafe = product('1', 'Café', barcode: '7891910000197', brand: 'Pilão');
    await repository.save(cafe);

    expect(await repository.findById('1'), cafe);
    expect(await repository.findByBarcode('7891910000197'), cafe);
    expect(await repository.findByBarcode('4006381333931'), isNull);
  });

  test('save atualiza um produto existente', () async {
    await repository.save(product('1', 'Cafe'));
    await repository.save(product('1', 'Café torrado'));

    final all = await repository.watchAll().first;
    expect(all.map((p) => p.name), ['Café torrado']);
  });

  test('impede o mesmo código de barras em dois produtos', () async {
    await repository.save(product('1', 'Café', barcode: '7891910000197'));

    expect(
      () => repository.save(product('2', 'Outro', barcode: '7891910000197')),
      throwsA(isA<DuplicateBarcodeException>()),
    );
  });

  test('produtos sem código de barras não conflitam', () async {
    await repository.save(product('1', 'Banana'));
    await repository.save(product('2', 'Maçã'));

    expect(await repository.watchAll().first, hasLength(2));
  });

  test('watchAll ordena por nome e filtra por nome, marca ou código', () async {
    await repository.save(product('1', 'feijão', brand: 'Camil'));
    await repository.save(product('2', 'Arroz', brand: 'Camil'));
    await repository.save(product('3', 'Café', barcode: '7891910000197'));

    final all = await repository.watchAll().first;
    expect(all.map((p) => p.name), ['Arroz', 'Café', 'feijão']);

    final byBrand = await repository.watchAll(query: 'camil').first;
    expect(byBrand.map((p) => p.id), ['2', '1']);

    final byBarcode = await repository.watchAll(query: '7891910000197').first;
    expect(byBarcode.map((p) => p.id), ['3']);
  });
}
