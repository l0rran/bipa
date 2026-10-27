import 'package:bipa/core/money/money.dart';
import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/products/domain/unit_price.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UnitPrice.of', () {
    test('converte gramas para preço por quilo', () {
      final unitPrice = UnitPrice.of(
        price: const Money.cents(799),
        packageSize: 395,
        unit: MeasureUnit.gram,
      );
      expect(unitPrice, const UnitPrice(price: Money.cents(2023), unit: MeasureUnit.kilogram));
    });

    test('converte mililitros para preço por litro', () {
      final unitPrice = UnitPrice.of(
        price: const Money.cents(450),
        packageSize: 350,
        unit: MeasureUnit.milliliter,
      );
      expect(unitPrice?.price, const Money.cents(1286));
      expect(unitPrice?.unit, MeasureUnit.liter);
    });

    test('divide pelo número de unidades da embalagem', () {
      final unitPrice = UnitPrice.of(
        price: const Money.cents(1800),
        packageSize: 12,
        unit: MeasureUnit.unit,
      );
      expect(unitPrice?.price, const Money.cents(150));
    });

    test('retorna null sem tamanho de embalagem', () {
      expect(
        UnitPrice.of(price: const Money.cents(100), packageSize: null, unit: MeasureUnit.kilogram),
        isNull,
      );
      expect(
        UnitPrice.of(price: const Money.cents(100), packageSize: 0, unit: MeasureUnit.kilogram),
        isNull,
      );
    });
  });

  test('Product.subtitle combina marca e embalagem', () {
    final now = DateTime(2026);
    final product = Product(
      id: '1',
      name: 'Leite condensado',
      brand: 'Moça',
      packageSize: 395,
      unit: MeasureUnit.gram,
      createdAt: now,
      updatedAt: now,
    );
    expect(product.packageLabel, '395 g');
    expect(product.subtitle, 'Moça · 395 g');

    final semDetalhes = Product(
      id: '2',
      name: 'Pão',
      unit: MeasureUnit.unit,
      createdAt: now,
      updatedAt: now,
    );
    expect(semDetalhes.subtitle, isNull);
  });
}
