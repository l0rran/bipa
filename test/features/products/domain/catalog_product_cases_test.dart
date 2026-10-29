import 'package:bipa/core/catalog/product_kind.dart';
import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:bipa/features/products/domain/package_origin.dart';
import 'package:bipa/features/products/domain/package_suggestion.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/products/domain/product_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

// Banco de casos reais do catálogo pronto (G12): linhas tiradas de
// assets/catalog/catalogo.sqlite (código, nome, marca e categoria como
// estão lá) e o produto de uma casa típica que `PackageSuggestion.fromCatalog`
// deve escolher, ou `null` quando a folha deve sugerir um produto novo.
//
// Calibragem do mantenedor (29/10): versão e linha da marca ("integral",
// "em pó", "Lavagem Perfeita", "Thompson") não mudam o produto; sabor,
// "condensado", "carreteiro", "refrigerante", "suco" e a categoria do
// catálogo mudam. Os casos `null` são os que não podem casar.

final _now = DateTime(2026, 10, 29);

/// A casa: nomes genéricos, como o ADR 0013 sugere, e alguns mais
/// específicos que costumam ficar ao lado deles.
final _household = [
  for (final name in [
    'Leite',
    'Leite condensado',
    'Creme de leite',
    'Arroz',
    'Feijão',
    'Feijão carioca',
    'Uva',
    'Laranja',
    'Café',
    'Açúcar',
    'Sal',
    'Óleo de soja',
    'Macarrão',
    'Biscoito recheado',
    'Cerveja',
    'Heineken',
    'Coca-cola',
    'Suco de uva',
    'Achocolatado',
    'Sabão em pó',
    'Detergente',
    'Iogurte',
    'Manteiga',
    'Farinha de trigo',
    'Molho de tomate',
    'Atum',
    'Papel higiênico',
  ])
    Product(id: name, name: name, unit: MeasureUnit.unit, createdAt: _now, updatedAt: _now),
];

typedef _Case = (String barcode, String name, String? brand, ProductKind? kind, String? expected);

const _cases = <_Case>[
  // Leite e derivados: a versão (UHT, integral, desnatado, em pó) é leite; o
  // condensado, o creme, o doce, o fermentado, o de coco e o espanhol não.
  ('7890000110266', 'Leite Condensado Semidesnatado ITALAC', 'Italac', ProductKind.sweets, 'Leite condensado'),
  ('7891000055922', 'Leite Condensado Integral Moça', 'Moça', ProductKind.sweets, 'Leite condensado'),
  ('7890002007236', 'Creme De Leite Piracanjuba', 'Piracanjuba', ProductKind.sweets, 'Creme de leite'),
  ('7891000126905', 'CREME DE LEITE UHT NESTLE', 'Nestlé', ProductKind.shelfStable, 'Creme de leite'),
  ('7891000101506', 'Leite em pó desnatado', 'Nestlé Molico', ProductKind.dairy, 'Leite'),
  ('7891025101604', 'Leite Uht Paulista 1lt Integral Edge', 'PAULISTA', ProductKind.shelfStable, 'Leite'),
  ('7891000154106', 'Doce De Leite Moça De Colher Lata 390g', 'NESTLE', null, null),
  ('7891025103073', 'Leite Fermentado Morango Activia Bandeja 800g 8 Unidades', 'ACTIVIA', null, null),
  ('7892300002791', 'Leite de Coco', 'Sinhá', ProductKind.shelfStable, null),
  ('7891000107263', 'Leche Condensada', 'Nestlé', null, null),
  ('7891000005422', 'Crema de leche', 'Nestlé', null, null),
  ('7891000342176', 'Leche en polvo', 'Nestlé', null, null),
  // Arroz e feijão: a versão (branco, integral, preto) é o mesmo produto; o
  // pronto, o temperado e o doce não.
  ('7895000318629', 'Arroz Branco Qualita 1kg', 'QUALITA', ProductKind.grains, 'Arroz'),
  ('7893500018483', 'Arroz Integral Tio João Tipo 1 1kg', 'TIO JOAO', ProductKind.grains, 'Arroz'),
  ('7893500012672', 'Arroz Carreteiro Tio João Cozinha Sabor 175g', 'TIO JOAO', null, null),
  ('7896091301286', 'Arroz Doce Caramelizado Miyako', 'MIYAKO', null, null),
  ('7891100794905', 'Feijão Carioca Camil 1Kg', 'Camil', null, 'Feijão carioca'),
  ('7893500120889', 'Feijão Preto', 'Tio João', ProductKind.grains, 'Feijão'),
  ('0004932000060', 'Feijão Preto Pronto Camil Temperado e Cozido', 'Camil', ProductKind.grains, null),
  ('7891103351495', 'Feijão carioca temperado', null, null, null),
  // Frutas e bebidas: a variedade é a fruta; sabor, suco e geleia não.
  ('7892857080389', 'Uva Thompson sem semente', 'Benassi', null, 'Uva'),
  ('78909052', 'Fanta Uva', 'Fanta', null, null),
  ('7894900030013', 'Fanta sabor laranja', 'Fanta', ProductKind.drinks, null),
  ('7891089446987', 'uva passa branca sem sementes', null, null, null),
  ('7896104804599', 'Geleia de uva', 'Ritter', ProductKind.sweets, null),
  ('7891141007477', 'Suco De Uva Integral', 'Aurora', null, 'Suco de uva'),
  ('7891141023910', 'SUCO INTEGRAL CASA DE BENTO UVA TINTO 1L', 'CASA DE BENTO', null, 'Suco de uva'),
  ('7894900011517', 'Refrigerante Coca-Cola 2Lt', 'Coca-Cola', null, 'Coca-cola'),
  ('78905498', 'Heineken Original 600ml', 'Heineken', ProductKind.drinks, 'Heineken'),
  ('7891149104932', 'Cerveja Zero Álcool', 'Brahma', ProductKind.drinks, 'Cerveja'),
  // Café, açúcar, sal e óleo: o solúvel e o café com leite não são café.
  ('7891018001386', 'Café Torrado E Moído Tradicional Café Brasileiro Pacote 500g', 'CAFE BRASILEIRO', null, 'Café'),
  ('7891000315606', 'Cafe Soluvel Nescafe Vidro 200G Matinal', 'Nescafe', ProductKind.coffee, null),
  ('7891000006290', 'Café Com Leite Solúvel Nescafé Lata 300g', 'Nestlé', ProductKind.coffee, null),
  ('7891910001972', 'Açúcar Refinado União 1kg', 'UNIÃO', null, 'Açúcar'),
  ('7891910030019', 'Açucar Cristal', 'União', null, 'Açúcar'),
  ('78903180', 'Sal Cisne Refinado Extra', 'Cisne', null, 'Sal'),
  ('7896018900028', 'Óleo de soja', 'Leve', ProductKind.oils, 'Óleo de soja'),
  // Mercearia e doces.
  ('7891079000205', 'Macarrão Instantâneo Lámen Carne Nissin Miojo Pacote 85g', 'AJINOMOTO', ProductKind.pasta, null),
  ('7891000079089', 'Biscoito Recheado Leite Moça', 'Nestlé', null, 'Biscoito recheado'),
  ('7891962036083', 'Biscoito recheado sabor chocolate', 'Visconti', null, null),
  (
    '7891000067178',
    'Achocolatado Pó Nescau Pacote 800g Embalagem Econômica',
    'Nestlé',
    ProductKind.sweets,
    'Achocolatado',
  ),
  ('7891080007705', 'Farinha de trigo tradicional', 'Bunge', ProductKind.baking, 'Farinha de trigo'),
  ('7891103224737', 'Molho de tomate', null, null, 'Molho de tomate'),
  // Laticínios: "Sal" está em "Manteiga Sem Sal", mas a manteiga começa o nome.
  ('7891025114291', 'Manteiga Extra Sem Sal Paulista 200g', 'PAULISTA', ProductKind.dairy, 'Manteiga'),
  ('7891000072950', 'Iogurte Natural Integral', 'Nestlé', ProductKind.sweets, 'Iogurte'),
  ('7891000094396', 'Iogurte Parcialmente Desnatado Morango Ninho Fruti 250g', 'NESTLE', null, null),
  // Limpeza: a linha da marca ("Lavagem Perfeita", "Cristal") não muda o tipo.
  ('7896098909768', 'Sabão em pó', 'TIXAN', ProductKind.laundry, 'Sabão em pó'),
  ('7891150069053', 'Sabão Em Pó Omo Lavagem Perfeita 4kg', 'Unilever', null, 'Sabão em pó'),
  ('7891022100372', 'Detergente Limpol Cristal', 'Limpol', ProductKind.cleaning, 'Detergente'),
];

void main() {
  test('o banco tem entre 30 e 50 casos, sem código repetido', () {
    expect(_cases.length, inInclusiveRange(30, 50));
    expect({for (final row in _cases) row.$1}.length, _cases.length);
  });

  for (final (barcode, name, brand, kind, expected) in _cases) {
    test('$barcode "$name" → ${expected ?? 'produto novo'}', () {
      final suggestion = PackageSuggestion.fromCatalog(
        CatalogPackage(barcode: barcode, name: name, brand: brand, kind: kind, source: PackageOrigin.openFoodFacts),
        products: _household,
      );

      expect(suggestion.product?.name, expected);
      // Sem produto escolhido, sempre há um nome novo para conferir.
      if (expected == null) expect(suggestion.newProductName, isNotEmpty);
    });
  }
}
