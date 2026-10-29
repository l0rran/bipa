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

  test('o produto novo ganha o acento das palavras comuns', () {
    expect(PackageSuggestion.from('FEIJAO CARIOCA CAMIL 1KG', products: const []).newProductName, 'Feijão');
    expect(PackageSuggestion.from('BISCOITO MAIZENA 200G', products: const []).newProductName, 'Biscoito');
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

    test('sem o produto, abre com o recorte', () {
      expect(query('FEIJAO CARIOCA CAMIL 1KG', const []), 'Feijão carioca');
      expect(query('BANANA PRATA KG', const []), 'Banana prata');
    });

    test('o recorte que já acha produtos não é trocado', () {
      // "Leite cond" acha o condensado pela busca: a pessoa confere e escolhe.
      expect(query('LEITE COND MOCA 395G', ['Leite condensado', 'Leite integral']), 'Leite cond');
    });

    test('sem resultado para o recorte, o único produto com a maioria das palavras', () {
      // O nome vem abreviado: "achoc" e "po" são 2 de 3.
      expect(query('ACHOC PO MALTADO 400G', ['Achocolatado em pó', 'Café']), 'Achocolatado em pó');
      // Metade não é maioria: abre só com a palavra que acha (G9).
      expect(query('CAFE GOURMET 500G', ['Café torrado']), 'Café');
      // Empate: não adivinha um deles; abre com a palavra que acha os dois (G9).
      expect(query('ACHOC PO MALTADO 400G', ['Achocolatado em pó', 'Achocolatado pó diet']), 'Achoc');
    });

    test('sem nome lido, ou só com o tamanho, abre vazio', () {
      expect(query(null, ['Arroz']), '');
      expect(query('  ', ['Arroz']), '');
      expect(query('1KG', ['Arroz']), '');
    });
  });

  group('nome do produto a partir da etiqueta (G6)', () {
    test('tira marca conhecida, tamanho, números e palavras da embalagem', () {
      expect(productNameFromLabel('FEIJAO CARIOCA CAMIL 1KG'), 'Feijão carioca');
      expect(productNameFromLabel('ARROZ BRANCO TIO JOAO 5KG'), 'Arroz branco');
      expect(productNameFromLabel('LEITE UHT INTEGRAL ITALAC 1L'), 'Leite uht integral');
      expect(productNameFromLabel('PCT FEIJAO PRETO KICALDO 1 KG'), 'Feijão preto');
      expect(productNameFromLabel('TOMATE CEREJA BDJ 180G'), 'Tomate cereja');
      // A palavra que liga fica entre as que ficam; o resto sai com a marca.
      expect(productNameFromLabel('SABAO EM PO OMO 1,6KG'), 'Sabão em pó');
      expect(productNameFromLabel('MOLHO DE TOMATE POMAROLA 340G'), 'Molho de tomate');
    });

    test('guarda a variedade do granel', () {
      expect(productNameFromLabel('BANANA PRATA KG'), 'Banana prata');
      expect(productNameFromLabel('BANANA NANICA KG'), 'Banana nanica');
      expect(productNameFromLabel('QUEIJO PRATO KG'), 'Queijo prato');
      expect(productNameFromLabel('QUEIJO MINAS FRESCAL KG'), 'Queijo minas frescal');
      expect(productNameFromLabel('QUEIJO MUSSARELA FATIADO KG'), 'Queijo mussarela fatiado');
      expect(productNameFromLabel('TOMATE ITALIANO KG'), 'Tomate italiano');
      expect(productNameFromLabel('CARNE MOIDA PATINHO KG'), 'Carne moída patinho');
      expect(productNameFromLabel('CARNE ACEM KG'), 'Carne acém');
    });

    test('na dúvida, a palavra fica: uma marca desconhecida entra no nome', () {
      expect(productNameFromLabel('FEIJAO CARIOCA SAO JORGE 1KG'), 'Feijão carioca sao jorge');
    });

    test('só com a marca, ela é o nome', () {
      expect(productNameFromLabel('NESCAU 400G'), 'Nescau');
    });

    test('põe o acento das palavras comuns, sem inventar nas outras', () {
      expect(productNameFromLabel('MACARRAO PARAFUSO RENATA 500G'), 'Macarrão parafuso');
      expect(productNameFromLabel('ACUCAR REFINADO UNIAO 1KG'), 'Açúcar refinado');
      expect(productNameFromLabel('PAO FRANCES KG'), 'Pão frances');
      expect(productNameFromLabel('LIMAO TAHITI KG'), 'Limão tahiti');
      expect(productNameFromLabel('MAMAO PAPAYA KG'), 'Mamão papaya');
      expect(productNameFromLabel('MELAO AMARELO KG'), 'Melão amarelo');
      expect(productNameFromLabel('FILE DE PEITO DE FRANGO KG'), 'Filé de peito de frango');
      expect(productNameFromLabel('PURE DE BATATA 200G'), 'Purê de batata');
      expect(productNameFromLabel('CAFE TORRADO 500G'), 'Café torrado');
      expect(productNameFromLabel('ACAI NA TIGELA 500ML'), 'Açaí na tigela');
      // "carioca", "batata" e "tahiti" não têm acento na tabela: ficam como vieram.
      expect(productNameFromLabel('BATATA LAVADA KG'), 'Batata lavada');
    });

    test('o acento que a etiqueta tem fica', () {
      expect(productNameFromLabel('FEIJÃO CARIOCA CAMIL 1KG'), 'Feijão carioca');
      expect(productNameFromLabel('Pêra Williams Kg'), 'Pêra williams');
    });

    test('sem nome lido, ou só com o tamanho, fica vazio', () {
      expect(productNameFromLabel(null), '');
      expect(productNameFromLabel('  '), '');
      expect(productNameFromLabel('1KG'), '');
    });
  });

  group('granel: a variedade seguinte não cai no produto da primeira (G6)', () {
    String query(String hint, List<String> names) =>
        productQueryFromLabel(hint, products: [for (final name in names) _product(name)]);

    test('com a outra variedade cadastrada, abre com a palavra comum e o recorte segue sendo outro nome', () {
      for (final (hint, other, word) in [
        ('BANANA NANICA KG', 'Banana prata', 'Banana'),
        ('QUEIJO PRATO KG', 'Queijo mussarela', 'Queijo'),
        ('QUEIJO MINAS KG', 'Queijo prato', 'Queijo'),
        ('TOMATE CEREJA KG', 'Tomate italiano', 'Tomate'),
        ('CARNE ACEM KG', 'Carne moída patinho', 'Carne'),
      ]) {
        final text = query(hint, [other]);
        // A lista mostra o parecido para comparar (G9)...
        expect(text, word, reason: hint);
        expect(matchesProductSearch(text, name: other), isTrue, reason: '$hint → $text');
        // ...mas "Criar" propõe a variedade lida, que não é a cadastrada (G6).
        expect(sameSearchWords(other, productNameFromLabel(hint)), isFalse, reason: hint);
      }
    });

    test('com só o nome genérico cadastrado, abre com ele e o recorte tem a palavra a mais', () {
      expect(query('BANANA NANICA KG', ['Banana']), 'Banana');
      expect(sameSearchWords('Banana', productNameFromLabel('BANANA NANICA KG')), isFalse);
      expect(query('CARNE MOIDA PATINHO KG', ['Carne']), 'Carne');
      expect(sameSearchWords('Carne', productNameFromLabel('CARNE MOIDA PATINHO KG')), isFalse);
    });

    test('a mesma variedade acha o produto dela, com as mesmas palavras', () {
      expect(query('BANANA PRATA KG', ['Banana prata', 'Banana nanica']), 'Banana prata');
      expect(sameSearchWords('Banana prata', productNameFromLabel('BANANA PRATA KG')), isTrue);
    });
  });

  group('uma palavra a mais na etiqueta não esconde o produto que existe (G9)', () {
    String query(String hint, List<String> names) =>
        productQueryFromLabel(hint, products: [for (final name in names) _product(name)]);

    test('abre com a palavra que acha o produto e o recorte segue como nome a criar', () {
      expect(query('LIMAO TAITI KG', ['Limão tahiti']), 'Limão');
      expect(productNameFromLabel('LIMAO TAITI KG'), 'Limão taiti');
      expect(query('MUSSARELA TIROLEZ KG', ['Queijo mussarela']), 'Mussarela');
      expect(productNameFromLabel('MUSSARELA TIROLEZ KG'), 'Mussarela tirolez');
    });

    test('a palavra escolhida acha o produto na busca', () {
      for (final (hint, name) in [('LIMAO TAITI KG', 'Limão tahiti'), ('MUSSARELA TIROLEZ KG', 'Queijo mussarela')]) {
        expect(matchesProductSearch(query(hint, [name]), name: name), isTrue, reason: hint);
      }
    });

    test('com a abreviação de balança, fica a palavra que acha', () {
      expect(query('QJO MUSS FAT KG', ['Queijo mussarela']), 'Muss');
    });

    test('entre várias palavras que acham, fica a que acha menos produtos', () {
      const names = ['Queijo prato', 'Queijo minas', 'Queijo mussarela'];
      expect(query('QUEIJO TIROLEZ MUSS FAT', names), 'Muss');
    });

    test('sem palavra que ache, ou com uma só, fica o recorte', () {
      expect(query('LIMAO TAITI KG', ['Arroz']), 'Limão taiti');
      expect(query('PITAYA KG', ['Arroz']), 'Pitaya');
    });

    test('o recorte que já acha produtos, ou o produto de nome inteiro na etiqueta, não mudam', () {
      expect(query('LIMAO TAHITI KG', ['Limão tahiti']), 'Limão tahiti');
      expect(query('LIMAO TAHITI KG', ['Limão']), 'Limão');
    });
  });
}
