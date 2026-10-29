import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:bipa/features/products/domain/package_origin.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/products/domain/product_package.dart';
import 'package:bipa/features/products/domain/product_repository.dart';
import 'package:bipa/features/products/domain/register_package.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fakes.dart';

void main() {
  final now = DateTime(2026, 10, 28, 9);
  late InMemoryProductRepository products;
  late RegisterPackage register;

  setUp(() {
    products = InMemoryProductRepository();
    register = RegisterPackage(products: products, ids: SequentialIdGenerator(), clock: () => now);
  });

  test('a embalagem nova entra no produto que já existe', () async {
    products.products['arroz'] = Product(
      id: 'arroz',
      name: 'Arroz branco',
      unit: MeasureUnit.kilogram,
      createdAt: now,
      updatedAt: now,
    );

    final (product, package) = await register(
      const NewPackageInput(
        barcode: '7896006711155',
        productId: 'arroz',
        brand: ' Tio João ',
        size: 5,
        unit: MeasureUnit.kilogram,
      ),
    );

    expect(product.id, 'arroz');
    expect(
      (package.productId, package.barcode, package.brand, package.label),
      ('arroz', '7896006711155', 'Tio João', 'Tio João · 5 kg'),
    );
    expect(products.products, hasLength(1));
  });

  test('sem produto escolhido, cria um com o nome sugerido', () async {
    final (product, package) = await register(
      const NewPackageInput(barcode: '7891089200015', newProductName: 'Café', unit: MeasureUnit.gram, size: 500),
    );

    expect(products.products[product.id]?.name, 'Café');
    expect(products.packages[package.id]?.productId, product.id);
    // O produto conta em kg; a embalagem fica em gramas.
    expect(product.unit, MeasureUnit.kilogram);
    expect(package.unit, MeasureUnit.gram);
  });

  test('a embalagem é da pessoa, ou do catálogo quando a folha veio preenchida por ele', () async {
    final (_, typed) = await register(
      const NewPackageInput(barcode: '7891089200015', newProductName: 'Café', unit: MeasureUnit.gram),
    );
    final (_, fromCatalog) = await register(
      const NewPackageInput(
        barcode: '7896006711155',
        newProductName: 'Arroz branco',
        unit: MeasureUnit.kilogram,
        origin: PackageOrigin.openFoodFacts,
      ),
    );

    expect(products.packages[typed.id]?.origin, PackageOrigin.person);
    expect(products.packages[fromCatalog.id]?.origin, PackageOrigin.openFoodFacts);
  });

  test('um código que já é de outra embalagem não cria nada', () async {
    products.products['arroz'] = Product(
      id: 'arroz',
      name: 'Arroz',
      unit: MeasureUnit.kilogram,
      createdAt: now,
      updatedAt: now,
    );
    products.packages['tio-joao'] = ProductPackage(
      id: 'tio-joao',
      productId: 'arroz',
      barcode: '7896006711155',
      unit: MeasureUnit.kilogram,
      createdAt: now,
      updatedAt: now,
    );

    await expectLater(
      register(const NewPackageInput(barcode: '7896006711155', newProductName: 'Outro', unit: MeasureUnit.unit)),
      throwsA(isA<DuplicateBarcodeException>()),
    );
    expect(products.products, hasLength(1));
  });

  test('pede o produto e um tamanho positivo', () async {
    await expectLater(
      register(const NewPackageInput(barcode: '7891089200015', unit: MeasureUnit.unit)),
      throwsA(isA<MissingPackageProductException>()),
    );
    await expectLater(
      register(const NewPackageInput(newProductName: 'Café', size: 0, unit: MeasureUnit.gram)),
      throwsA(isA<InvalidPackageSizeException>()),
    );
  });
}
