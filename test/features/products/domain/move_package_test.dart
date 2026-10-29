import 'package:bipa/features/prices/domain/register_price_observation.dart';
import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:bipa/features/products/domain/move_package.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/products/domain/product_package.dart';
import 'package:bipa/features/products/domain/product_repository.dart';
import 'package:bipa/features/products/domain/register_package.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fakes.dart';

void main() {
  final now = DateTime(2026, 10, 28, 9);
  late InMemoryProductRepository products;
  late MovePackage move;

  setUp(() {
    products = InMemoryProductRepository();
    move = MovePackage(products: products, ids: SequentialIdGenerator(), clock: () => now);
    for (final (id, name) in [('integral', 'Leite integral'), ('ninho', 'Leite Ninho')]) {
      products.products[id] = Product(id: id, name: name, unit: MeasureUnit.kilogram, createdAt: now, updatedAt: now);
    }
    // O Leite Ninho de 400 g foi bipado no Leite integral.
    products.packages['ninho-400'] = ProductPackage(
      id: 'ninho-400',
      productId: 'integral',
      barcode: '7891000100101',
      brand: 'Ninho',
      size: 400,
      unit: MeasureUnit.gram,
      createdAt: now,
      updatedAt: now,
    );
  });

  test('a embalagem vai para o produto escolhido', () async {
    final into = await move(packageId: 'ninho-400', intoProductId: 'ninho');

    expect(into?.id, 'ninho');
    expect(products.packages['ninho-400']?.productId, 'ninho');
  });

  test('para o mesmo produto, não muda nada', () async {
    final into = await move(packageId: 'ninho-400', intoProductId: 'integral');

    expect(into, isNull);
    expect(products.packages['ninho-400']?.productId, 'integral');
  });

  test('sem produto escolhido, cria um com o nome e a grandeza base da embalagem', () async {
    final into = await move(packageId: 'ninho-400', newProductName: ' Leite em pó ');

    expect((into?.name, into?.unit), ('Leite em pó', MeasureUnit.kilogram));
    expect(products.products[into?.id], into);
    expect(products.packages['ninho-400']?.productId, into?.id);
  });

  test('sem produto e sem nome, não cria nada', () async {
    await expectLater(
      move(packageId: 'ninho-400', newProductName: '  '),
      throwsA(isA<MissingPackageProductException>()),
    );
    expect(products.products, hasLength(2));
    expect(products.packages['ninho-400']?.productId, 'integral');
  });

  test('um produto que não existe ou uma embalagem que não existe avisam', () async {
    await expectLater(move(packageId: 'ninho-400', intoProductId: 'apagado'), throwsA(isA<ProductNotFoundException>()));
    await expectLater(move(packageId: 'nenhuma', intoProductId: 'ninho'), throwsA(isA<PackageNotFoundException>()));
  });
}
