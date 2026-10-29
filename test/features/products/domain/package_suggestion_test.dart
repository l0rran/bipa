import 'package:bipa/core/catalog/product_kind.dart';
import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:bipa/features/products/domain/package_origin.dart';
import 'package:bipa/features/products/domain/package_suggestion.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/products/domain/product_catalog.dart';
import 'package:bipa/features/products/domain/product_package.dart';
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
      expect(productNameFromLabel('PAO FRANCES KG'), 'Pão francês');
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

    test('põe o acento das palavras de balança e de gôndola de granel (G11)', () {
      for (final (hint, name) in [
        ('PAO FRANCES KG', 'Pão francês'),
        ('GRAO DE BICO KG', 'Grão de bico'),
        ('LINGUICA TOSCANA KG', 'Linguiça toscana'),
        ('ABOBORA CABOTIA KG', 'Abóbora cabotia'),
        ('LOMBO SUINO KG', 'Lombo suíno'),
        ('COSTELA SUINA KG', 'Costela suína'),
        ('QUEIJO PARMESAO KG', 'Queijo parmesão'),
        ('QUEIJO MINAS PADRAO KG', 'Queijo minas padrão'),
        ('FILE DE SALMAO KG', 'Filé de salmão'),
        ('FILE DE TILAPIA KG', 'Filé de tilápia'),
        ('RUCULA MACO', 'Rúcula maco'),
        ('AGRIAO KG', 'Agrião'),
        ('JILO KG', 'Jiló'),
        ('CONTRAFILE KG', 'Contrafilé'),
        ('ALMONDEGA BOVINA KG', 'Almôndega bovina'),
      ]) {
        expect(productNameFromLabel(hint), name, reason: hint);
      }
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

  group('do catálogo pronto (ADR 0024)', () {
    const rice = CatalogPackage(
      barcode: '7893500020110',
      name: 'Arroz Branco Tipo 1 Tio João',
      brand: 'Tio João',
      size: 5,
      unit: MeasureUnit.kilogram,
      kind: ProductKind.grains,
      source: PackageOrigin.openFoodFacts,
    );

    test('o produto da pessoa vem pelo nome, e marca, tamanho e origem vêm do catálogo', () {
      final products = [_product('Arroz'), _product('Arroz branco'), _product('Feijão')];

      expect(
        PackageSuggestion.fromCatalog(rice, products: products),
        PackageSuggestion(
          product: products[1],
          brand: 'Tio João',
          size: 5,
          unit: MeasureUnit.kilogram,
          origin: PackageOrigin.openFoodFacts,
        ),
      );
    });

    test('sem produto parecido, sugere o nome do catálogo sem marca, tamanho e embalagem', () {
      final suggestion = PackageSuggestion.fromCatalog(rice, products: [_product('Feijão')]);

      expect((suggestion.product, suggestion.newProductName), (null, 'Arroz branco'));
    });

    test('num empate pelo nome, fica o produto do tipo da categoria do catálogo', () {
      // "Leite" e "Leite condensado" têm todas as palavras no nome, mas só
      // um deles é doce.
      const condensed = CatalogPackage(
        barcode: '7891000100103',
        name: 'Leite Condensado Moça',
        kind: ProductKind.sweets,
        source: PackageOrigin.openFoodFacts,
      );
      final products = [_product('Leite moça'), _product('Leite condensado')];

      expect(PackageSuggestion.fromCatalog(condensed, products: products).product?.name, 'Leite condensado');
    });

    test('a marca em caixa alta ou com várias vira uma só, com a inicial maiúscula', () {
      const shouting = CatalogPackage(
        barcode: '7896005800010',
        name: 'CAFE TORRADO E MOIDO PILAO',
        brand: 'PILÃO, JDE',
        source: PackageOrigin.openFoodFacts,
      );

      final suggestion = PackageSuggestion.fromCatalog(shouting, products: const []);

      expect((suggestion.brand, suggestion.newProductName), ('Pilão', 'Café torrado e moído'));
    });

    test('sem tamanho no catálogo, ele vem da quantidade em texto, ou do nome', () {
      const byQuantity = CatalogPackage(
        barcode: '1',
        name: 'Detergente Ypê 500ml',
        quantity: '5 l',
        source: PackageOrigin.openProductsFacts,
      );
      const byName = CatalogPackage(
        barcode: '2',
        name: 'Detergente Ypê 500ml',
        source: PackageOrigin.openProductsFacts,
      );
      const none = CatalogPackage(barcode: '3', name: 'Detergente Ypê', source: PackageOrigin.openProductsFacts);

      PackageSuggestion of(CatalogPackage package) => PackageSuggestion.fromCatalog(package, products: const []);
      expect((of(byQuantity).size, of(byQuantity).unit), (5, MeasureUnit.liter));
      expect((of(byName).size, of(byName).unit), (500, MeasureUnit.milliliter));
      expect((of(none).size, of(none).unit, of(none).origin), (null, null, PackageOrigin.openProductsFacts));
    });

    test('se só sobra a marca, ela é o nome do produto novo', () {
      const nescau = CatalogPackage(
        barcode: '7891000053508',
        name: 'Nescau',
        brand: 'Nestlé',
        size: 400,
        unit: MeasureUnit.gram,
        source: PackageOrigin.openFoodFacts,
      );
      const onlyBrand = CatalogPackage(
        barcode: '1',
        name: 'Camil',
        brand: 'Camil',
        source: PackageOrigin.openFoodFacts,
      );

      expect(PackageSuggestion.fromCatalog(nescau, products: const []).newProductName, 'Nescau');
      expect(PackageSuggestion.fromCatalog(onlyBrand, products: const []).newProductName, 'Camil');
    });
  });

  group('o catálogo não põe a embalagem num produto mais genérico (G12)', () {
    // A casa que o ADR 0013 sugere, com nomes genéricos.
    final products = [_product('Leite'), _product('Arroz'), _product('Feijão'), _product('Uva')];

    PackageSuggestion of(String barcode, String name, {String? brand, ProductKind? kind}) =>
        PackageSuggestion.fromCatalog(
          CatalogPackage(barcode: barcode, name: name, brand: brand, kind: kind, source: PackageOrigin.openFoodFacts),
          products: products,
        );

    test('o leite condensado não vira embalagem de leite', () {
      final suggestion = of(
        '7890000110266',
        'Leite Condensado Semidesnatado ITALAC',
        brand: 'Italac',
        kind: ProductKind.sweets,
      );
      expect((suggestion.product, suggestion.newProductName), (null, 'Leite condensado semidesnatado'));
    });

    test('o arroz carreteiro pronto não vira embalagem de arroz', () {
      final suggestion = of('7893500012672', 'Arroz Carreteiro Tio João Cozinha Sabor 175g', brand: 'TIO JOAO');
      expect((suggestion.product, suggestion.brand), (null, 'Tio João'));
      expect(suggestion.newProductName, 'Arroz carreteiro cozinha sabor');
    });

    test('o feijão pronto não vira embalagem de feijão', () {
      final suggestion = of(
        '0004932000060',
        'Feijão Preto Pronto Camil Temperado e Cozido',
        brand: 'Camil',
        kind: ProductKind.grains,
      );
      expect(suggestion.product, isNull);
    });

    test('a Fanta Uva não vira embalagem da fruta', () {
      final suggestion = of('78909052', 'Fanta Uva', brand: 'Fanta');
      expect((suggestion.product, suggestion.newProductName), (null, 'Fanta uva'));
    });

    test('a categoria do catálogo recusa o produto de outro tipo', () {
      final orange = _product('Laranja');
      final suggestion = PackageSuggestion.fromCatalog(
        const CatalogPackage(
          barcode: '1',
          name: 'Laranja',
          brand: 'Fanta',
          kind: ProductKind.drinks,
          source: PackageOrigin.openFoodFacts,
        ),
        products: [orange],
      );
      expect(suggestion.product, isNull);
    });

    test('o produto que cobre o nome continua sendo escolhido', () {
      expect(of('7895000318629', 'Arroz Branco Qualita 1kg', brand: 'QUALITA').product?.name, 'Arroz');
      expect(of('1', 'Leite UHT', brand: 'Italac', kind: ProductKind.shelfStable).product?.name, 'Leite');
    });
  });

  group('o catálogo só põe a embalagem num produto da mesma grandeza (G16)', () {
    const powder = CatalogPackage(
      barcode: '7891000101506',
      name: 'Leite em pó desnatado',
      brand: 'Nestlé Molico',
      size: 280,
      unit: MeasureUnit.gram,
      kind: ProductKind.dairy,
      source: PackageOrigin.openFoodFacts,
    );
    Product milk({MeasureUnit unit = MeasureUnit.unit}) =>
        Product(id: 'leite', name: 'Leite', unit: unit, createdAt: _now, updatedAt: _now);
    ProductPackage packageOf(String productId, MeasureUnit unit, {double? size}) => ProductPackage(
      id: '$productId-${unit.name}',
      productId: productId,
      size: size,
      unit: unit,
      createdAt: _now,
      updatedAt: _now,
    );
    Product? productFor(CatalogPackage package, Product product, [List<ProductPackage> packages = const []]) =>
        PackageSuggestion.fromCatalog(package, products: [product], packages: packages).product;

    test('o leite em pó, em gramas, não entra no leite em litros e vira produto próprio', () {
      final suggestion = PackageSuggestion.fromCatalog(
        powder,
        products: [milk()],
        packages: [packageOf('leite', MeasureUnit.liter, size: 1)],
      );

      expect(suggestion.product, isNull);
      expect(suggestion.newProductName, startsWith('Leite em pó'));
    });

    test('a grandeza é a das embalagens; sem elas, a do produto', () {
      expect(productFor(powder, milk(), [packageOf('leite', MeasureUnit.kilogram, size: 0.4)]), isNotNull);
      expect(productFor(powder, milk(unit: MeasureUnit.liter)), isNull);
      expect(productFor(powder, milk(unit: MeasureUnit.kilogram)), isNotNull);
      // As embalagens valem mais que a unidade do produto.
      expect(
        productFor(powder, milk(unit: MeasureUnit.kilogram), [packageOf('leite', MeasureUnit.liter, size: 1)]),
        isNull,
      );
    });

    test('o produto sem embalagem e sem unidade aceita qualquer grandeza', () {
      expect(productFor(powder, milk()), isNotNull);
      // Uma embalagem sem tamanho em "un" não disse grandeza nenhuma.
      expect(productFor(powder, milk(), [packageOf('leite', MeasureUnit.unit)]), isNotNull);
    });

    test('unidade só com unidade', () {
      const eggs = CatalogPackage(
        barcode: '1',
        name: 'Ovos brancos',
        size: 12,
        unit: MeasureUnit.unit,
        source: PackageOrigin.openFoodFacts,
      );
      final product = Product(id: 'ovos', name: 'Ovos', unit: MeasureUnit.unit, createdAt: _now, updatedAt: _now);

      expect(productFor(eggs, product, [packageOf('ovos', MeasureUnit.unit, size: 30)]), isNotNull);
      expect(productFor(eggs, product, [packageOf('ovos', MeasureUnit.kilogram, size: 1)]), isNull);
    });

    test('sem tamanho no catálogo, a grandeza não decide', () {
      const noSize = CatalogPackage(barcode: '1', name: 'Leite em pó', source: PackageOrigin.openFoodFacts);

      expect(productFor(noSize, milk(), [packageOf('leite', MeasureUnit.liter, size: 1)]), isNotNull);
    });
  });

  group('nome novo do catálogo inteiro, com a marca quando sem ela sobra metade (G13)', () {
    String? nameOf(String name, {String? brand}) => PackageSuggestion.fromCatalog(
      CatalogPackage(barcode: '1', name: name, brand: brand, source: PackageOrigin.openFoodFacts),
      products: const [],
    ).newProductName;

    test('sem a marca, só o sabor: a marca fica no lugar dela', () {
      expect(nameOf('Fanta Uva', brand: 'Fanta'), 'Fanta uva');
      expect(nameOf('Fanta sabor laranja', brand: 'Fanta'), 'Fanta laranja');
      expect(nameOf('Guaraná Antarctica zero', brand: 'Antarctica'), 'Guaraná antarctica zero');
    });

    test('sem a marca, só a linha: a linha comum sai, as outras ficam', () {
      expect(nameOf('Heineken Original 600ml', brand: 'Heineken'), 'Heineken');
      expect(nameOf('Nescafe Classic', brand: 'Nescafe'), 'Nescafé');
      expect(nameOf('Kit Kat Dark', brand: 'Kit Kat'), 'Kit kat dark');
    });

    test('uma palavra de produto basta, sem a marca', () {
      expect(nameOf('Arroz Tio João 5kg', brand: 'Tio João'), 'Arroz');
      expect(nameOf('Refrigerante Coca-Cola 2Lt', brand: 'Coca-Cola'), 'Refrigerante');
    });

    test('a marca sai onde ela aparece inteira, e a primeira palavra do nome fica', () {
      expect(
        nameOf('Café Torrado E Moído Extraforte Café Brasileiro Pacote 500g', brand: 'CAFE BRASILEIRO'),
        'Café torrado e moído extraforte',
      );
      expect(nameOf('Feijão Carioca Camil 1Kg', brand: 'Camil Alimentos'), 'Feijão carioca');
    });

    test('nome em espanhol fica como veio', () {
      expect(nameOf('Leche Condensada', brand: 'Nestlé'), 'Leche condensada');
    });
  });

  group('grafia da marca do catálogo (G13)', () {
    String? brandOf(String brand) => PackageSuggestion.fromCatalog(
      CatalogPackage(barcode: '1', name: 'Leite', brand: brand, source: PackageOrigin.openFoodFacts),
      products: const [],
    ).brand;

    test('a marca conhecida sem acento ganha a grafia dela', () {
      expect(brandOf('NESTLE'), 'Nestlé');
      expect(brandOf('TIO JOAO'), 'Tio João');
      expect(brandOf('Tio Joao, Josapar'), 'Tio João');
      expect(brandOf('QUALITA'), 'Qualitá');
      expect(brandOf('3 CORACOES'), '3 Corações');
      expect(brandOf('MOCA'), 'Moça');
    });

    test('o acento que a marca tem fica, e a desconhecida em caixa alta vira só a inicial', () {
      expect(brandOf('NESTLÉ'), 'Nestlé');
      expect(brandOf('Piracanjuba'), 'Piracanjuba');
      expect(brandOf('CASA DE BENTO'), 'Casa De Bento');
    });
  });
}
