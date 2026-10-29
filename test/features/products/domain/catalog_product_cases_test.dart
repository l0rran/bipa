import 'package:bipa/core/catalog/product_kind.dart';
import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:bipa/features/products/domain/package_origin.dart';
import 'package:bipa/features/products/domain/package_suggestion.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/products/domain/product_catalog.dart';
import 'package:bipa/features/products/domain/product_package.dart';
import 'package:flutter_test/flutter_test.dart';

// Banco de casos reais do catálogo pronto (G12): linhas tiradas de
// assets/catalog/catalogo.sqlite (código, nome, marca, categoria e tamanho
// como estão lá) e o produto de uma casa típica que
// `PackageSuggestion.fromCatalog` deve escolher, ou `null` quando a folha deve
// sugerir um produto novo.
//
// Calibragem do mantenedor (29/10): versão e linha da marca ("integral",
// "em pó", "Lavagem Perfeita", "Thompson") não mudam o produto; sabor,
// "condensado", "carreteiro", "refrigerante", "suco" e a categoria do
// catálogo mudam. A grandeza também muda (G16): massa com massa, volume com
// volume, unidade com unidade. O leite em pó, em gramas, não entra no "Leite"
// em litros e vira produto próprio. Os casos `null` são os que não podem
// casar.

final _now = DateTime(2026, 10, 29);

/// A casa: nomes genéricos, como o ADR 0013 sugere, e alguns mais
/// específicos que costumam ficar ao lado deles. Alguns já têm uma embalagem,
/// que diz em que grandeza o produto se mede (G16); "Açúcar" e "Óleo de soja"
/// ainda não têm, mas a unidade do produto diz; os outros aceitam qualquer
/// grandeza.
const _household = <(String, String?)>[
  ('Leite', '1 L'),
  ('Leite condensado', null),
  ('Creme de leite', null),
  ('Arroz', null),
  ('Feijão', null),
  ('Feijão carioca', null),
  ('Uva', null),
  ('Laranja', null),
  ('Café', '500 g'),
  ('Açúcar', 'kg'),
  ('Sal', null),
  ('Óleo de soja', 'L'),
  ('Macarrão', null),
  ('Biscoito recheado', null),
  ('Cerveja', null),
  ('Heineken', '600 ml'),
  ('Coca-cola', '2 L'),
  ('Suco de uva', null),
  ('Achocolatado', '400 g'),
  ('Sabão em pó', '1,6 kg'),
  ('Detergente', '500 ml'),
  ('Iogurte', null),
  ('Manteiga', null),
  ('Farinha de trigo', null),
  ('Molho de tomate', null),
  ('Atum', null),
  ('Papel higiênico', null),
];

typedef _Case = (String barcode, String name, String? brand, ProductKind? kind, String? size, String? expected);

const _cases = <_Case>[
  // Leite e derivados: a versão (UHT, integral, desnatado) é leite; o
  // condensado, o creme, o doce, o fermentado, o de coco e o espanhol não. O
  // leite em pó é leite pelo nome, mas em gramas não cabe no "Leite" em
  // litros (G16).
  ('7890000110266', 'Leite Condensado Semidesnatado ITALAC', 'Italac', ProductKind.sweets, '395 g', 'Leite condensado'),
  ('7891000055922', 'Leite Condensado Integral Moça', 'Moça', ProductKind.sweets, '395 g', 'Leite condensado'),
  ('7890002007236', 'Creme De Leite Piracanjuba', 'Piracanjuba', ProductKind.sweets, '200 g', 'Creme de leite'),
  ('7891000126905', 'CREME DE LEITE UHT NESTLE', 'Nestlé', ProductKind.shelfStable, '200 g', 'Creme de leite'),
  ('7891000101506', 'Leite em pó desnatado', 'Nestlé Molico', ProductKind.dairy, '280 g', null),
  ('7891025101604', 'Leite Uht Paulista 1lt Integral Edge', 'PAULISTA', ProductKind.shelfStable, '1 L', 'Leite'),
  ('7898184232354', 'Leite pasteurizado integral homogeneizado', 'DuCampo', ProductKind.shelfStable, '1 L', 'Leite'),
  ('7891000154106', 'Doce De Leite Moça De Colher Lata 390g', 'NESTLE', null, '390 g', null),
  ('7891025103073', 'Leite Fermentado Morango Activia Bandeja 800g 8 Unidades', 'ACTIVIA', null, '800 g', null),
  ('7892300002791', 'Leite de Coco', 'Sinhá', ProductKind.shelfStable, '200 ml', null),
  ('7891000107263', 'Leche Condensada', 'Nestlé', null, '395 g', null),
  ('7891000005422', 'Crema de leche', 'Nestlé', null, '300 g', null),
  ('7891000342176', 'Leche en polvo', 'Nestlé', null, null, null),
  // Arroz e feijão: a versão (branco, integral, preto) é o mesmo produto; o
  // pronto, o temperado e o doce não.
  ('7895000318629', 'Arroz Branco Qualita 1kg', 'QUALITA', ProductKind.grains, '1 kg', 'Arroz'),
  ('7893500018483', 'Arroz Integral Tio João Tipo 1 1kg', 'TIO JOAO', ProductKind.grains, '1 kg', 'Arroz'),
  ('7893500012672', 'Arroz Carreteiro Tio João Cozinha Sabor 175g', 'TIO JOAO', null, '175 g', null),
  ('7896091301286', 'Arroz Doce Caramelizado Miyako', 'MIYAKO', null, '150 g', null),
  ('7891100794905', 'Feijão Carioca Camil 1Kg', 'Camil', null, '1 kg', 'Feijão carioca'),
  ('7893500120889', 'Feijão Preto', 'Tio João', ProductKind.grains, '1 kg', 'Feijão'),
  ('0004932000060', 'Feijão Preto Pronto Camil Temperado e Cozido', 'Camil', ProductKind.grains, '380 g', null),
  ('7891103351495', 'Feijão carioca temperado', null, null, null, null),
  // Frutas e bebidas: a variedade é a fruta; sabor, suco e geleia não.
  ('7892857080389', 'Uva Thompson sem semente', 'Benassi', null, null, 'Uva'),
  ('78909052', 'Fanta Uva', 'Fanta', null, null, null),
  ('7894900030013', 'Fanta sabor laranja', 'Fanta', ProductKind.drinks, '350 ml', null),
  ('7891089446987', 'uva passa branca sem sementes', null, null, null, null),
  ('7896104804599', 'Geleia de uva', 'Ritter', ProductKind.sweets, '400 g', null),
  ('7891141007477', 'Suco De Uva Integral', 'Aurora', null, null, 'Suco de uva'),
  ('7891141023910', 'SUCO INTEGRAL CASA DE BENTO UVA TINTO 1L', 'CASA DE BENTO', null, '1 L', 'Suco de uva'),
  ('7894900011517', 'Refrigerante Coca-Cola 2Lt', 'Coca-Cola', null, '2 L', 'Coca-cola'),
  ('78905498', 'Heineken Original 600ml', 'Heineken', ProductKind.drinks, '600 ml', 'Heineken'),
  ('7891149104932', 'Cerveja Zero Álcool', 'Brahma', ProductKind.drinks, '350 ml', 'Cerveja'),
  // Café, açúcar, sal e óleo: o solúvel e o café com leite não são café.
  (
    '7891018001386',
    'Café Torrado E Moído Tradicional Café Brasileiro Pacote 500g',
    'CAFE BRASILEIRO',
    null,
    '500 g',
    'Café',
  ),
  ('7891000315606', 'Cafe Soluvel Nescafe Vidro 200G Matinal', 'Nescafe', ProductKind.coffee, '200 g', null),
  ('7891000006290', 'Café Com Leite Solúvel Nescafé Lata 300g', 'Nestlé', ProductKind.coffee, '300 g', null),
  ('7891910001972', 'Açúcar Refinado União 1kg', 'UNIÃO', null, '1 kg', 'Açúcar'),
  ('7891910030019', 'Açucar Cristal', 'União', null, '1 kg', 'Açúcar'),
  ('78903180', 'Sal Cisne Refinado Extra', 'Cisne', null, '100 g', 'Sal'),
  ('7896018900028', 'Óleo de soja', 'Leve', ProductKind.oils, '900 ml', 'Óleo de soja'),
  // Mercearia e doces. O achocolatado em pó, em gramas, não recebe o pronto
  // para beber, em ml (G16).
  (
    '7891079000205',
    'Macarrão Instantâneo Lámen Carne Nissin Miojo Pacote 85g',
    'AJINOMOTO',
    ProductKind.pasta,
    '85 g',
    null,
  ),
  ('7891000079089', 'Biscoito Recheado Leite Moça', 'Nestlé', null, null, 'Biscoito recheado'),
  ('7891962036083', 'Biscoito recheado sabor chocolate', 'Visconti', null, null, null),
  (
    '7891000067178',
    'Achocolatado Pó Nescau Pacote 800g Embalagem Econômica',
    'Nestlé',
    ProductKind.sweets,
    '800 g',
    'Achocolatado',
  ),
  ('7896275980962', 'Achocolatado frimesa 200ml', null, null, '200 ml', null),
  ('7891080007705', 'Farinha de trigo tradicional', 'Bunge', ProductKind.baking, '1 kg', 'Farinha de trigo'),
  ('7891103224737', 'Molho de tomate', null, null, null, 'Molho de tomate'),
  // Laticínios: "Sal" está em "Manteiga Sem Sal", mas a manteiga começa o nome.
  ('7891025114291', 'Manteiga Extra Sem Sal Paulista 200g', 'PAULISTA', ProductKind.dairy, '200 g', 'Manteiga'),
  ('7891000072950', 'Iogurte Natural Integral', 'Nestlé', ProductKind.sweets, '170 g', 'Iogurte'),
  ('7891000094396', 'Iogurte Parcialmente Desnatado Morango Ninho Fruti 250g', 'NESTLE', null, '250 g', null),
  // Limpeza: a linha da marca ("Lavagem Perfeita", "Cristal") não muda o
  // tipo. O detergente em pó, em kg, não entra no "Detergente" em ml (G16).
  ('7896098909768', 'Sabão em pó', 'TIXAN', ProductKind.laundry, '1,6 kg', 'Sabão em pó'),
  ('7891150069053', 'Sabão Em Pó Omo Lavagem Perfeita 4kg', 'Unilever', null, '4 kg', 'Sabão em pó'),
  ('7891022100372', 'Detergente Limpol Cristal', 'Limpol', ProductKind.cleaning, '500 ml', 'Detergente'),
  (
    '7891035024351',
    'DETERGENTE PÓ PARA MÁQUINA DE LAVAR LOUÇAS FINISH POWER POWDER ADVANCED POTE 1KG',
    'FINISH',
    null,
    '1 kg',
    null,
  ),
];

/// Uma casa que chama os produtos pela marca (G17), cada um com uma
/// embalagem do produto pelo qual a marca é conhecida, e o "Leite" em litros
/// ao lado do "Ninho" em pó.
const _brandHousehold = <(String, String?)>[
  ('Leite', '1 L'),
  ('Ninho', '380 g'),
  ('Nescau', '400 g'),
  ('Toddy', '370 g'),
  ('Danone', '170 g'),
  ('Coca-cola', '2 L'),
  ('Omo', '1,6 kg'),
];

/// Calibragem do mantenedor (29/10): a marca no nome do produto não dispensa
/// as palavras que mudam o tipo, a categoria nem a grandeza. Conta como do
/// produto só a palavra do produto pelo qual a marca é conhecida ("leite"
/// para o "Ninho", "achocolatado" para o "Nescau").
const _brandCases = <_Case>[
  // Ninho: o leite em pó; não o iogurte, a fórmula, o composto, o brownie
  // nem o Ninho líquido, em litros.
  ('7891000094396', 'Iogurte Parcialmente Desnatado Morango Ninho Fruti 250g', 'NESTLE', null, '250 g', null),
  ('7891000001080', 'Fórmula Infantil Ninho Fases 1+', 'NESTLE', ProductKind.dairy, '400 g', null),
  ('0609963517664', 'Brownie Recheado - Leite Ninho', 'Brownie 3 Irmãs', null, null, null),
  ('7891000062661', 'Composto Lácteo Ninho Fases 1 Lata 800g', 'NESTLE', ProductKind.dairy, '800 g', null),
  ('7891000340035', 'Bebida Láctea Uht Morango E Banana Ninho Fruti Caixa 190ml', 'NINHO', null, '190 ml', null),
  ('7891000119495', 'NESTLÉ NINHO Forti+ UHT Zero Lactose', 'Nestle5', ProductKind.dairy, '1 L', null),
  ('7891000340882', 'leite ninho', 'nestle', ProductKind.dairy, '380 g', 'Ninho'),
  ('7891000393482', 'Leite po ninho instant lt', null, null, '380 g', 'Ninho'),
  ('7891000284933', 'Ninho Forti+', 'Nestlé', ProductKind.shelfStable, '380 g', 'Ninho'),
  // Nescau: o achocolatado em pó; não a bebida láctea, o biscoito nem o
  // cereal.
  ('7891000023167', 'Bebida Láctea Uht Chocolate Light Nescau Caixa 200ml', 'NESTLE', null, '200 ml', null),
  ('7891000101926', 'Nescau 170ml', 'Nestlé', null, '270 ml', null),
  ('7891000089279', 'Biscoito Nescau', 'Nestle', ProductKind.sweets, '140 g', null),
  ('7891000008119', 'Nescau Cereal', 'Nestlé', ProductKind.grains, '270 g', null),
  ('7891000266182', 'Cereal Nescau 400g', null, null, '400 g', null),
  ('7891000338087', 'Achocolatado em pó Nescau 550g Refil', 'Nestlé', ProductKind.sweets, '550 g', 'Nescau'),
  ('7891000009437', 'Nescau', 'Nestlé', null, '400 g', 'Nescau'),
  // Toddy: o mesmo, com a marca que o catálogo às vezes troca pela linha.
  ('7892840814137', 'Toddy Original', 'Toddy', ProductKind.sweets, '1,02 kg', 'Toddy'),
  ('7894321711478', 'Achocolatado Toddy 800g', 'Toddy', ProductKind.sweets, '800 g', 'Toddy'),
  ('7892840819798', 'Achocolatado Pó Original Toddy Pacote 480g Econômica', 'ORIGINAL', null, '480 g', 'Toddy'),
  (
    '7892840818678',
    'Biscoito Cookie Chocolate Com Gotas De Chocolate Toddy Pacote 133g Embalagem Econômica',
    'COOKIE',
    null,
    '133 g',
    null,
  ),
  // Danone: o iogurte natural; o de sabor, a bebida láctea, o leite e o leite
  // em pó da marca não.
  ('7891025109556', 'Iogurte Natural Desnatado Danone', 'Danone', null, '160 g', 'Danone'),
  (
    '7891025102496',
    'Iogurte Parcialmente Desnatado Morango Danone Garrafa 900g',
    'DANONE',
    ProductKind.sweets,
    '900 g',
    null,
  ),
  ('7891025121626', 'Bebida Láctea Fermentada Morango Danone Bandeja 510g 6 Unidades', 'MORANGO', null, '510 g', null),
  ('7891025105640', 'Leite Uht Semidesnatado Danone Caixa Com Tampa 1l', 'DANONE', null, '1 L', 'Leite'),
  ('7891025107897', 'Leite Em Po Aptamil 800g 2 Danone', 'DANONE', null, '800 g', null),
  // Coca-cola: a versão (zero) e o tamanho não mudam o produto.
  ('7894900700015', 'Coca-Cola Zero Açúcar', 'Coca-Cola', ProductKind.drinks, '350 ml', 'Coca-cola'),
  ('7894900011708', 'Coca-cola', 'Coca-Cola', ProductKind.drinks, '3 L', 'Coca-cola'),
  ('7894900011517', 'Refrigerante Coca-Cola 2Lt', 'Coca-Cola', null, '2 L', 'Coca-cola'),
  // Omo: o sabão; não o tira-manchas.
  ('7891150064522', 'OMO Lavagem Perfeita', 'Omo', null, '400 g', 'Omo'),
  ('7891150069053', 'Sabão Em Pó Omo Lavagem Perfeita 4kg', 'Unilever', null, '4 kg', 'Omo'),
  ('7891039023701', 'LAVA ROUPAS OMO MILTIAÇÃO', 'Unilever', null, '1 kg', 'Omo'),
  ('7891150041431', 'Tira Mancha Omo', null, null, null, null),
];

/// "1,6 kg" em tamanho e unidade; só a unidade ("kg") vem sem tamanho.
(double?, MeasureUnit) _measure(String text) {
  final parts = text.split(' ');
  final unit = MeasureUnit.values.firstWhere((unit) => unit.symbol == parts.last);
  return (parts.length == 1 ? null : double.parse(parts.first.replaceAll(',', '.')), unit);
}

/// Os produtos e as embalagens da casa: o produto com só a unidade ("kg")
/// se mede nela, sem embalagem; com o tamanho ("1 L"), tem uma embalagem
/// dele.
(List<Product>, List<ProductPackage>) _home(List<(String, String?)> household) {
  final products = <Product>[];
  final packages = <ProductPackage>[];
  for (final (name, measure) in household) {
    final (size, unit) = measure == null ? (null, MeasureUnit.unit) : _measure(measure);
    products.add(
      Product(id: name, name: name, unit: size == null ? unit : MeasureUnit.unit, createdAt: _now, updatedAt: _now),
    );
    if (size != null) {
      packages.add(
        ProductPackage(id: '$name-1', productId: name, size: size, unit: unit, createdAt: _now, updatedAt: _now),
      );
    }
  }
  return (products, packages);
}

void _check(List<(String, String?)> household, List<_Case> cases) {
  final (products, packages) = _home(household);
  for (final (barcode, name, brand, kind, size, expected) in cases) {
    test('$barcode "$name" → ${expected ?? 'produto novo'}', () {
      final measure = size == null ? null : _measure(size);
      final suggestion = PackageSuggestion.fromCatalog(
        CatalogPackage(
          barcode: barcode,
          name: name,
          brand: brand,
          kind: kind,
          size: measure?.$1,
          unit: measure?.$2,
          source: PackageOrigin.openFoodFacts,
        ),
        products: products,
        packages: packages,
      );

      expect(suggestion.product?.name, expected);
      // Sem produto escolhido, sempre há um nome novo para conferir.
      if (expected == null) expect(suggestion.newProductName, isNotEmpty);
    });
  }
}

void main() {
  test('o banco tem entre 30 e 60 casos por casa, sem código repetido', () {
    for (final cases in [_cases, _brandCases]) {
      expect(cases.length, inInclusiveRange(30, 60));
      expect({for (final row in cases) row.$1}.length, cases.length);
    }
  });

  group('casa com nomes genéricos', () => _check(_household, _cases));
  group('casa com nomes de marca (G17)', () => _check(_brandHousehold, _brandCases));
}
