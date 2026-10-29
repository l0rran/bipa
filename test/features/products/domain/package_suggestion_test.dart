import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:bipa/features/products/domain/package_suggestion.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/products/domain/product_search.dart';
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

  group('texto inicial da escolha de produto a partir da etiqueta (G4)', () {
    String query(String? hint, List<String> names) =>
        productQueryFromLabel(hint, products: [for (final name in names) _product(name)]);

    test('com o produto cadastrado, abre com o nome dele, sem marca nem tamanho', () {
      expect(query('FEIJAO CARIOCA CAMIL 1KG', ['Arroz', 'Feijão carioca']), 'Feijão carioca');
      expect(query('CAFE PILAO TRADICIONAL 500G', ['Café', 'Açúcar']), 'Café');
      // O mais específico, como na sugestão de embalagem.
      expect(query('ARROZ BRANCO TIO JOAO 5KG', ['Arroz', 'Arroz branco']), 'Arroz branco');
    });

    test('o texto escolhido acha o produto na busca por todas as palavras', () {
      const names = ['Feijão carioca', 'Feijão preto', 'Açúcar refinado'];
      for (final hint in ['FEIJAO CARIOCA CAMIL 1KG', 'ACUCAR REFINADO UNIAO 1 KG', 'FEIJAO CARIOCA 1KG TP 1']) {
        final text = query(hint, names);
        expect(names.where((name) => matchesProductSearch(text, name: name)), isNotEmpty, reason: '$hint → $text');
      }
    });

    test('sem o produto, recorta: tira marca, tamanho, números e palavras da embalagem', () {
      expect(query('FEIJAO CARIOCA CAMIL 1KG', const []), 'Feijao carioca');
      expect(query('ARROZ BRANCO TIO JOAO 5KG', const []), 'Arroz branco');
      expect(query('LEITE UHT INTEGRAL ITALAC 1L', const []), 'Leite uht integral');
      expect(query('PCT FEIJAO PRETO KICALDO 1 KG', const []), 'Feijao preto');
      // A palavra que liga fica entre as que ficam; o resto sai com a marca.
      expect(query('SABAO EM PO OMO 1,6KG', const []), 'Sabao em po');
      // O acento da etiqueta, quando há, fica.
      expect(query('FEIJÃO CARIOCA CAMIL 1KG', const []), 'Feijão carioca');
    });

    test('o recorte que já acha produtos não é trocado', () {
      // "Leite" acha os dois: a pessoa escolhe, e nada é adivinhado.
      expect(query('LEITE COND MOCA 395G', ['Leite condensado', 'Leite integral']), 'Leite');
    });

    test('sem resultado para o recorte, o único produto com a maioria das palavras', () {
      // A marca vem primeiro e o nome, abreviado: "achoc" e "po" são 2 de 3.
      expect(query('NESCAU ACHOC PO 400G', ['Achocolatado em pó', 'Café']), 'Achocolatado em pó');
      // Metade não é maioria.
      expect(query('PILAO CAFE 500G', ['Café torrado']), 'Pilao');
      // Empate: fica o recorte, sem adivinhar.
      expect(query('NESCAU ACHOC PO 400G', ['Achocolatado em pó', 'Achocolatado pó diet']), 'Nescau po');
    });

    test('sem nome lido, ou só com o tamanho, abre vazio', () {
      expect(query(null, ['Arroz']), '');
      expect(query('  ', ['Arroz']), '');
      expect(query('1KG', ['Arroz']), '');
    });
  });
}
