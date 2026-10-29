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
  test('o banco tem entre 30 e 60 casos, sem código repetido', () {
    expect(_cases.length, inInclusiveRange(30, 60));
    expect({for (final row in _cases) row.$1}.length, _cases.length);
  });

  group('casa com nomes genéricos', () => _check(_household, _cases));
}
