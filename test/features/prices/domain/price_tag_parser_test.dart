import 'package:bipa/core/money/money.dart';
import 'package:bipa/features/prices/domain/price_tag.dart';
import 'package:bipa/features/prices/domain/price_tag_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// Monta as linhas de uma etiqueta de cima para baixo.
/// Cada item é (texto, altura da fonte).
List<OcrLine> tag(List<(String, double)> lines) => [
  for (final (index, (text, height)) in lines.indexed)
    OcrLine(text: text, top: index * 40.0, height: height),
];

void main() {
  const parser = PriceTagParser();

  test('etiqueta simples: preço, nome e código impresso', () {
    final reading = parser.parse(
      tag([
        ('LEITE COND MOCA 395G', 20),
        ('R\$ 7,99', 80),
        ('7891000100103', 12),
      ]),
    );

    expect(reading.price, const Money.cents(799));
    expect(reading.regularPrice, isNull);
    expect(reading.productNameHint, 'Leite Cond Moca 395g');
    expect(reading.barcode, '7891000100103');
    expect(reading.isEmpty, isFalse);
  });

  test('ignora o preço por quilo quando há preço da embalagem', () {
    final reading = parser.parse(
      tag([
        ('ARROZ TIO JOAO 5KG', 20),
        ('R\$ 27,90', 60),
        ('PREÇO POR KG R\$ 5,58', 12),
      ]),
    );

    expect(reading.price, const Money.cents(2790));
    expect(reading.candidates, [const Money.cents(2790)]);
  });

  test('usa o preço por quilo em produtos a granel', () {
    final reading = parser.parse(
      tag([
        ('ALCATRA BOVINA', 20),
        ('R\$ 39,90 /KG', 60),
      ]),
    );

    expect(reading.price, const Money.cents(3990));
  });

  test('identifica promoção "de/por"', () {
    final reading = parser.parse(
      tag([
        ('SABAO EM PO OMO 1,6KG', 20),
        ('DE R\$ 32,90', 16),
        ('POR R\$ 24,90', 50),
      ]),
    );

    expect(reading.price, const Money.cents(2490));
    expect(reading.regularPrice, const Money.cents(3290));
    expect(reading.productNameHint, 'Sabao Em Po Omo 1,6kg');
  });

  test('lê centavos impressos separados', () {
    final reading = parser.parse(
      tag([
        ('CAFE PILAO 500G', 20),
        ('R\$ 18 99', 70),
      ]),
    );

    expect(reading.price, const Money.cents(1899));
  });

  test('sem marcadores, escolhe o valor com a maior fonte', () {
    final reading = parser.parse(
      tag([
        ('BISCOITO RECHEADO', 18),
        ('3,99', 20),
        ('4,49', 70),
      ]),
    );

    expect(reading.price, const Money.cents(449));
    expect(reading.candidates, [const Money.cents(399), const Money.cents(449)]);
  });

  test('datas não são confundidas com preços', () {
    final reading = parser.parse(
      tag([
        ('BANANA PRATA', 20),
        ('VALIDO ATE 31.10.26', 12),
        ('R\$ 5,49', 60),
      ]),
    );

    expect(reading.candidates, [const Money.cents(549)]);
    expect(reading.productNameHint, 'Banana Prata');
  });

  test('volumes e pesos não são confundidos com preços', () {
    final reading = parser.parse(
      tag([
        ('AGUA MINERAL 1,50L', 20),
        ('R\$ 2,79', 60),
      ]),
    );

    expect(reading.candidates, [const Money.cents(279)]);
    expect(reading.productNameHint, 'Agua Mineral 1,50l');
  });

  test('corrige "RS" lido no lugar de "R\$"', () {
    final reading = parser.parse(tag([('RS 18 99', 70)]));
    expect(reading.price, const Money.cents(1899));
  });

  test('prefere o código lido pelo scanner e descarta códigos inválidos', () {
    final reading = parser.parse(
      tag([('R\$ 2,00', 50), ('7891000100103', 12)]),
      barcodes: ['123', '7891910000197'],
    );

    expect(reading.barcode, '7891910000197');
  });

  test('ordena as linhas pela posição vertical', () {
    final reading = parser.parse(const [
      OcrLine(text: 'R\$ 9,99', top: 50, height: 60),
      OcrLine(text: 'FEIJAO CARIOCA', top: 0, height: 20),
    ]);

    expect(reading.productNameHint, 'Feijao Carioca');
  });

  test('etiqueta sem preço nem código é vazia', () {
    final reading = parser.parse(tag([('PAO FRANCES', 20)]));

    expect(reading.price, isNull);
    expect(reading.isEmpty, isTrue);
    expect(reading.productNameHint, 'Pao Frances');
  });
}
