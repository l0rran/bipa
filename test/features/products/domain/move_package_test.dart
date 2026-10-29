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

    expect(into?.into.id, 'ninho');
    expect(products.packages['ninho-400']?.productId, 'ninho');
  });

  test('para o mesmo produto, não muda nada', () async {
    final into = await move(packageId: 'ninho-400', intoProductId: 'integral');

    expect(into, isNull);
    expect(products.packages['ninho-400']?.productId, 'integral');
  });

  test('sem produto escolhido, cria um com o nome e a grandeza base da embalagem', () async {
    final into = await move(packageId: 'ninho-400', newProductName: ' Leite em pó ');

    final created = into?.into;
    expect((created?.name, created?.unit), ('Leite em pó', MeasureUnit.kilogram));
    expect(products.products[created?.id], created);
    expect(products.packages['ninho-400']?.productId, created?.id);
    expect(into?.createdProduct, isTrue);
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

  group('desfazer', () {
    test('leva a embalagem de volta ao produto de origem', () async {
      final moved = await move(packageId: 'ninho-400', intoProductId: 'ninho');
      await move.undo(moved!);

      expect(products.packages['ninho-400']?.productId, 'integral');
      expect(products.emptyStockItemsDeleted, isEmpty);
    });

    test('tira o item de estoque que nasceu no destino só por causa da movida', () async {
      products.createsStockItem = true;
      final moved = await move(packageId: 'ninho-400', intoProductId: 'ninho');
      await move.undo(moved!);

      expect(products.emptyStockItemsDeleted, ['ninho']);
    });

    test('apaga o produto que a movida criou, se continuar vazio', () async {
      final moved = await move(packageId: 'ninho-400', newProductName: 'Leite em pó');
      final createdId = moved!.into.id;
      await move.undo(moved);

      expect(products.products.containsKey(createdId), isFalse);
      expect(products.packages['ninho-400']?.productId, 'integral');
    });

    test('guarda o produto criado que ganhou preço ou estoque nesse meio-tempo', () async {
      final moved = await move(packageId: 'ninho-400', newProductName: 'Leite em pó');
      products.productsWithData.add(moved!.into.id);
      await move.undo(moved);

      expect(products.products.containsKey(moved.into.id), isTrue);
    });

    test('avisa se a embalagem sumiu enquanto o aviso estava na tela', () async {
      final moved = await move(packageId: 'ninho-400', intoProductId: 'ninho');
      products.packages.remove('ninho-400');

      await expectLater(move.undo(moved!), throwsA(isA<PackageNotFoundException>()));
    });
  });

  group('produto de origem vazio', () {
    test('é vazio quando a última embalagem sai e não sobra preço nem estoque', () async {
      final moved = await move(packageId: 'ninho-400', intoProductId: 'ninho');

      expect(moved?.sourceEmpty, isTrue);
    });

    test('não é vazio se o produto ainda tem outra embalagem', () async {
      products.packages['integral-1l'] = ProductPackage(
        id: 'integral-1l',
        productId: 'integral',
        size: 1,
        unit: MeasureUnit.liter,
        createdAt: now,
        updatedAt: now,
      );
      final moved = await move(packageId: 'ninho-400', intoProductId: 'ninho');

      expect(moved?.sourceEmpty, isFalse);
    });

    test('não é vazio se ainda tem preço ou algo em casa', () async {
      products.productsWithData.add('integral');
      final moved = await move(packageId: 'ninho-400', intoProductId: 'ninho');

      expect(moved?.sourceEmpty, isFalse);
    });
  });
}
