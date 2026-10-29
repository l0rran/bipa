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
// A regra é conservadora: na dúvida, produto novo, que a pessoa troca com um
// toque. Os casos marcados "conservador" são os que uma regra mais esperta
// poderia acertar; ficam aqui para quem afinar a regra ver o que muda.

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
  // Leite e derivados: o condensado, o creme, o em pó e o espanhol não caem
  // no "Leite".
  ('7890000110266', 'Leite Condensado Semidesnatado ITALAC', 'Italac', ProductKind.sweets, 'Leite condensado'),
  ('7891000055922', 'Leite Condensado Integral Moça', 'Moça', ProductKind.sweets, 'Leite condensado'),
  ('7890002007236', 'Creme De Leite Piracanjuba', 'Piracanjuba', ProductKind.sweets, 'Creme de leite'),
  ('7891000126905', 'CREME DE LEITE UHT NESTLE', 'Nestlé', ProductKind.shelfStable, 'Creme de leite'),
  ('7891000101506', 'Leite em pó desnatado', 'Nestlé Molico', ProductKind.dairy, null),
  ('7891000066607', 'Leite UHT Desnatado', 'Molico', ProductKind.shelfStable, null),
  // Conservador: "integral" muda o arroz e o pão, então também conta no leite.
  ('7891025101604', 'Leite Uht Paulista 1lt Integral Edge', 'PAULISTA', ProductKind.shelfStable, null),
  ('7891000107263', 'Leche Condensada', 'Nestlé', null, null),
  ('7891000005422', 'Crema de leche', 'Nestlé', null, null),
  ('7891000342176', 'Leche en polvo', 'Nestlé', null, null),
  // Arroz e feijão: o branco e o tipo 1 são o arroz; o pronto, o temperado,
  // o integral não.
  ('7895000318629', 'Arroz Branco Qualita 1kg', 'QUALITA', ProductKind.grains, 'Arroz'),
  ('7891986001395', 'Arroz Branco', 'Camil Alimentos', ProductKind.grains, 'Arroz'),
  ('7893500012672', 'Arroz Carreteiro Tio João Cozinha Sabor 175g', 'TIO JOAO', null, null),
  ('7893500018483', 'Arroz Integral Tio João Tipo 1 1kg', 'TIO JOAO', ProductKind.grains, null),
  ('7891100794905', 'Feijão Carioca Camil 1Kg', 'Camil', null, 'Feijão carioca'),
  ('7893500120889', 'Feijão Preto', 'Tio João', ProductKind.grains, null),
  ('0004932000060', 'Feijão Preto Pronto Camil Temperado e Cozido', 'Camil', ProductKind.grains, null),
  ('7891103351495', 'Feijão carioca temperado', null, null, null),
  // Frutas e bebidas: sabor não é fruta.
  ('78909052', 'Fanta Uva', 'Fanta', null, null),
  ('7894900030013', 'Fanta sabor laranja', 'Fanta', ProductKind.drinks, null),
  ('7891089446987', 'uva passa branca sem sementes', null, null, null),
  // Conservador: a variedade conta, como no granel (G6).
  ('7892857080389', 'Uva Thompson sem semente', 'Benassi', null, null),
  ('7891141007477', 'Suco De Uva Integral', 'Aurora', null, 'Suco de uva'),
  ('7891141035494', 'Suco de uva branco com gás', 'Aurora', null, 'Suco de uva'),
  // Conservador: "integral" e "tinto" são duas palavras a mais.
  ('7891141023910', 'SUCO INTEGRAL CASA DE BENTO UVA TINTO 1L', 'CASA DE BENTO', null, null),
  ('7894900011517', 'Refrigerante Coca-Cola 2Lt', 'Coca-Cola', null, 'Coca-cola'),
  ('7894900011708', 'Coca-cola', 'Coca-Cola', ProductKind.drinks, 'Coca-cola'),
  ('78905498', 'Heineken Original 600ml', 'Heineken', ProductKind.drinks, 'Heineken'),
  ('7891149104932', 'Cerveja Zero Álcool', 'Brahma', ProductKind.drinks, null),
  // Café, açúcar, sal e óleo: torrado e moído, refinado e extra são o comum.
  ('7891018001386', 'Café Torrado E Moído Tradicional Café Brasileiro Pacote 500g', 'CAFE BRASILEIRO', null, 'Café'),
  ('7891000315606', 'Cafe Soluvel Nescafe Vidro 200G Matinal', 'Nescafe', ProductKind.coffee, null),
  ('7891910001972', 'Açúcar Refinado União 1kg', 'UNIÃO', null, 'Açúcar'),
  ('7891910030019', 'Açucar Cristal', 'União', null, null),
  ('78903180', 'Sal Cisne Refinado Extra', 'Cisne', null, 'Sal'),
  ('7896018900028', 'Óleo de soja', 'Leve', ProductKind.oils, 'Óleo de soja'),
  // Mercearia e doces.
  ('7891079000205', 'Macarrão Instantâneo Lámen Carne Nissin Miojo Pacote 85g', 'AJINOMOTO', ProductKind.pasta, null),
  ('7891000079089', 'Biscoito Recheado Leite Moça', 'Nestlé', null, 'Biscoito recheado'),
  ('7891962036083', 'Biscoito recheado sabor chocolate', 'Visconti', null, null),
  ('7891000242599', 'Achocolatado', 'Nescau', null, 'Achocolatado'),
  // Conservador: "pó" muda o leite, então também conta no achocolatado.
  ('7891000067178', 'Achocolatado Pó Nescau Pacote 800g Embalagem Econômica', 'Nestlé', ProductKind.sweets, null),
  ('7891080007705', 'Farinha de trigo tradicional', 'Bunge', ProductKind.baking, 'Farinha de trigo'),
  ('7891103224737', 'Molho de tomate', null, null, 'Molho de tomate'),
  // Laticínios: "Sal" está em "Manteiga Sem Sal", mas não é o tipo dela.
  ('7891025114291', 'Manteiga Extra Sem Sal Paulista 200g', 'PAULISTA', ProductKind.dairy, null),
  ('7891000072950', 'Iogurte Natural Integral', 'Nestlé', ProductKind.sweets, null),
  ('7891000094396', 'Iogurte Parcialmente Desnatado Morango Ninho Fruti 250g', 'NESTLE', null, null),
  // Limpeza e higiene.
  ('7896098909768', 'Sabão em pó', 'TIXAN', ProductKind.laundry, 'Sabão em pó'),
  // Conservador: a linha da marca ("Lavagem Perfeita", "Cristal") conta.
  ('7891150069053', 'Sabão Em Pó Omo Lavagem Perfeita 4kg', 'Unilever', null, null),
  ('7891022100372', 'Detergente Limpol Cristal', 'Limpol', ProductKind.cleaning, null),
  ('7891022638004', 'detergente', 'limpol', null, 'Detergente'),
  ('7896026839259', 'papel higiênico', 'paloma', ProductKind.hygiene, 'Papel higiênico'),
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
