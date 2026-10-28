import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:bipa/features/products/domain/package_suggestion.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 10, 28);

Product _product(String name) =>
    Product(id: name, name: name, unit: MeasureUnit.kilogram, createdAt: _now, updatedAt: _now);

void main() {
  test('sem produto parecido, sugere um produto novo, a marca e o tamanho', () {
    final suggestion = PackageSuggestion.from('ARROZ BRANCO TIO JOAO 5KG', products: const []);

    expect(
      suggestion,
      const PackageSuggestion(newProductName: 'Arroz', brand: 'Tio Joao', size: 5, unit: MeasureUnit.kilogram),
    );
  });

  test('escolhe o produto mais específico cujo nome está na etiqueta', () {
    final products = [_product('Arroz'), _product('Arroz branco'), _product('Feijão')];

    final suggestion = PackageSuggestion.from('ARROZ BRANCO TIO JOAO 5KG', products: products);

    expect(suggestion.product?.name, 'Arroz branco');
    expect(suggestion.newProductName, isNull);
    expect(suggestion.brand, 'Tio Joao');
  });

  test('compara sem acento e lê tamanhos em g, L e un', () {
    final coffee = PackageSuggestion.from('CAFE PILAO TRADICIONAL 500G', products: [_product('Café')]);
    expect((coffee.product?.name, coffee.brand, coffee.size, coffee.unit), ('Café', 'Pilao', 500, MeasureUnit.gram));

    final milk = PackageSuggestion.from('LEITE UHT INTEGRAL ITALAC 1L', products: const []);
    expect((milk.newProductName, milk.brand, milk.unit), ('Leite', 'Italac', MeasureUnit.liter));

    final soap = PackageSuggestion.from('SABAO EM PO OMO 1,6KG', products: const []);
    expect((soap.brand, soap.size), ('Omo', 1.6));

    final eggs = PackageSuggestion.from('OVOS 12 UN', products: const []);
    expect((eggs.size, eggs.unit), (12, MeasureUnit.unit));
  });

  test('sem nome lido, não sugere nada', () {
    expect(PackageSuggestion.from(null, products: [_product('Arroz')]), PackageSuggestion.empty);
    expect(PackageSuggestion.from('  ', products: const []), PackageSuggestion.empty);
  });
}
