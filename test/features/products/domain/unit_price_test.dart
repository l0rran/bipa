import 'package:bipa/core/money/money.dart';
import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:bipa/features/products/domain/product_package.dart';
import 'package:bipa/features/products/domain/unit_price.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UnitPrice.of', () {
    test('converte gramas para preço por quilo', () {
      final unitPrice = UnitPrice.of(price: const Money.cents(799), packageSize: 395, unit: MeasureUnit.gram);
      expect(unitPrice, const UnitPrice(price: Money.cents(2023), unit: MeasureUnit.kilogram));
    });

    test('converte mililitros para preço por litro', () {
      final unitPrice = UnitPrice.of(price: const Money.cents(450), packageSize: 350, unit: MeasureUnit.milliliter);
      expect(unitPrice?.price, const Money.cents(1286));
      expect(unitPrice?.unit, MeasureUnit.liter);
    });

    test('divide pelo número de unidades da embalagem', () {
      final unitPrice = UnitPrice.of(price: const Money.cents(1800), packageSize: 12, unit: MeasureUnit.unit);
      expect(unitPrice?.price, const Money.cents(150));
    });

    test('retorna null sem tamanho de embalagem', () {
      expect(UnitPrice.of(price: const Money.cents(100), packageSize: null, unit: MeasureUnit.kilogram), isNull);
      expect(UnitPrice.of(price: const Money.cents(100), packageSize: 0, unit: MeasureUnit.kilogram), isNull);
    });
  });

  test('a embalagem descreve marca e tamanho e calcula o preço por kg', () {
    final now = DateTime(2026);
    final package = ProductPackage(
      id: '1',
      productId: 'leite-condensado',
      brand: 'Moça',
      size: 395,
      unit: MeasureUnit.gram,
      createdAt: now,
      updatedAt: now,
    );
    expect(package.sizeLabel, '395 g');
    expect(package.label, 'Moça · 395 g');
    expect(package.sizeInBaseUnit, closeTo(0.395, 1e-9));
    // O formato de moeda usa espaço não separável depois do "R$".
    expect(package.unitPrice(const Money.cents(799))?.format().replaceAll('\u00a0', ' '), r'R$ 20,23/kg');

    final bare = ProductPackage(id: '2', productId: 'pao', unit: MeasureUnit.unit, createdAt: now, updatedAt: now);
    expect(bare.label, isNull);
    expect(bare.unitPrice(const Money.cents(100)), isNull);
  });
}
