import 'package:bipa/core/money/money.dart';
import 'package:bipa/features/prices/domain/price_condition.dart';
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
    expect(reading.offers, const [PriceOffer(price: Money.cents(2490), regularPrice: Money.cents(3290))]);
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

  test('preço seguido de KG ou UN continua sendo preço', () {
    expect(parser.parse(tag([('TOMATE ITALIANO', 20), ('R\$ 8,99 KG', 70)])).price, const Money.cents(899));
    expect(parser.parse(tag([('ACUCAR UNIAO 1KG', 20), ('R\$ 4,99 UN', 70)])).price, const Money.cents(499));
  });

  test('lê milhar e ignora o valor da parcela', () {
    final reading = parser.parse(
      tag([
        ('GELADEIRA FROST FREE 375L', 20),
        ('R\$ 1.299,90', 70),
        ('OU 10X DE R\$ 129,99 SEM JUROS', 16),
      ]),
    );

    expect(reading.price, const Money.cents(129990));
    expect(reading.regularPrice, isNull);
    expect(reading.candidates, [const Money.cents(129990)]);
  });

  test('junta dígitos que o OCR separou depois do R\$', () {
    expect(parser.parse(tag([('R\$ 1 0,99', 70)])).price, const Money.cents(1099));
  });

  group('centavos sobrescritos lidos como linha à parte', () {
    test('são juntados ao inteiro ao lado', () {
      final reading = parser.parse(const [
        OcrLine(text: 'CAFE PILAO 500G', top: 10, height: 30, left: 20, width: 400),
        OcrLine(text: 'R\$ 18', top: 100, height: 120, left: 300, width: 200),
        OcrLine(text: ',99', top: 104, height: 50, left: 506, width: 80),
      ]);

      expect(reading.price, const Money.cents(1899));
    });

    test('também sem a vírgula', () {
      final reading = parser.parse(const [
        OcrLine(text: '18', top: 100, height: 120, left: 300, width: 150),
        OcrLine(text: '99', top: 100, height: 50, left: 455, width: 70),
      ]);

      expect(reading.price, const Money.cents(1899));
    });

    test('números longe um do outro não são juntados', () {
      final reading = parser.parse(const [
        OcrLine(text: 'R\$ 18', top: 100, height: 120, left: 300, width: 200),
        OcrLine(text: '99', top: 300, height: 50, left: 506, width: 80),
      ]);

      expect(reading.price, isNull);
    });
  });

  test('o nome ignora rótulos da etiqueta e lixo do OCR', () {
    final reading = parser.parse(
      tag([
        ('LEVE 3 PAGUE 2', 30),
        ('oooooooooooo', 20),
        ('CAFE PILAO 500G', 20),
        ('R\$ 18,99', 70),
      ]),
    );

    expect(reading.productNameHint, 'Cafe Pilao 500g');
  });

  group('preços com condição (ADR 0011)', () {
    test('atacado na mesma linha do preço', () {
      final reading = parser.parse(
        tag([
          ('CAFE PILAO 500G', 20),
          ('R\$ 5,49', 60),
          ('ATACADO A PARTIR DE 6 UN R\$ 4,99', 50),
        ]),
      );

      expect(reading.price, const Money.cents(549));
      expect(reading.offers, const [
        PriceOffer(price: Money.cents(549)),
        PriceOffer(price: Money.cents(499), condition: Wholesale(minimumQuantity: 6)),
      ]);
    });

    test('preço clube vira oferta para membros, não promoção', () {
      final reading = parser.parse(
        tag([
          ('FEIJAO KICALDO 1KG', 20),
          ('R\$ 8,49', 40),
          ('PREÇO CLUBE', 20),
          ('R\$ 7,22', 80),
        ]),
      );

      expect(reading.price, const Money.cents(849));
      expect(reading.regularPrice, isNull);
      expect(reading.offers, const [
        PriceOffer(price: Money.cents(849)),
        PriceOffer(price: Money.cents(722), condition: LoyaltyMembers()),
      ]);
    });

    test('"de R\$" solto vira o preço normal da oferta principal', () {
      final reading = parser.parse(
        tag([
          ('CAFE PILAO 500G', 20),
          ('DE R\$ 9,99', 30),
          ('NO APP', 20),
          ('R\$ 7,99', 80),
        ]),
      );

      expect(reading.offers, const [
        PriceOffer(price: Money.cents(799), condition: LoyaltyMembers(), regularPrice: Money.cents(999)),
      ]);
      expect(reading.regularPrice, const Money.cents(999));
    });

    test('preços pequenos do bloco de informações não viram ofertas', () {
      final reading = parser.parse(
        tag([
          ('DET LIQ MINUANO 500ML', 20),
          ('R\$ 1,79', 60),
          ('Atacado 3,58', 10),
        ]),
      );

      expect(reading.offers, const [PriceOffer(price: Money.cents(179))]);
      expect(reading.candidates, [const Money.cents(179), const Money.cents(358)]);
    });
  });

  group('etiquetas reais do Assaí', () {
    test('atacado, cartão e varejo: um preço por condição, varejo primeiro', () {
      final reading = parser.parse(const [
        OcrLine(text: 'FEIJAO CARIOCA KICALDO T1 1KG', left: 35, top: 170, width: 340, height: 22),
        OcrLine(text: 'FEIJAO CARIOCA KICALDO T1 1KG', left: 40, top: 200, width: 230, height: 12),
        OcrLine(text: 'VAREJO R\$', left: 360, top: 205, width: 70, height: 12),
        OcrLine(text: '8.05', left: 370, top: 216, width: 66, height: 32),
        OcrLine(text: 'PASSAI CRED R\$', left: 222, top: 240, width: 100, height: 14),
        OcrLine(text: '7.85', left: 235, top: 254, width: 72, height: 36),
        OcrLine(text: 'ATACADO R\$', left: 70, top: 278, width: 95, height: 14),
        OcrLine(text: 'À UNIDADE', left: 365, top: 285, width: 70, height: 10),
        OcrLine(text: '7.85', left: 88, top: 297, width: 76, height: 34),
        OcrLine(text: 'À UNIDADE', left: 238, top: 320, width: 70, height: 12),
        OcrLine(text: 'A PARTIR DE', left: 90, top: 345, width: 70, height: 10),
        OcrLine(text: '10', left: 113, top: 357, width: 28, height: 22),
        OcrLine(text: 'UNIDADES', left: 95, top: 381, width: 62, height: 10),
      ]);

      expect(reading.offers, const [
        PriceOffer(price: Money.cents(805), condition: AnyCustomer()),
        PriceOffer(price: Money.cents(785), condition: LoyaltyMembers()),
        PriceOffer(price: Money.cents(785), condition: Wholesale(minimumQuantity: 10)),
      ]);
      expect(reading.price, const Money.cents(805));
      expect(reading.productNameHint, 'Feijao Carioca Kicaldo T1 1kg');
    });

    test('sem varejo, o preço do cartão é o principal', () {
      final reading = parser.parse(const [
        OcrLine(text: 'DET LIQ MINUANO 500ml COCO', left: 80, top: 85, width: 670, height: 40),
        OcrLine(text: 'DET LIQ MINUANO 500ml COCO', left: 85, top: 145, width: 470, height: 16),
        OcrLine(text: 'ATACADO R\$', left: 130, top: 183, width: 185, height: 16),
        OcrLine(text: 'PASSAI CRED R\$', left: 400, top: 192, width: 285, height: 18),
        OcrLine(text: '1,79', left: 175, top: 210, width: 135, height: 52),
        OcrLine(text: '1,79', left: 475, top: 222, width: 160, height: 58),
        OcrLine(text: 'A PARTIR DE', left: 165, top: 296, width: 130, height: 10),
        OcrLine(text: '06', left: 195, top: 315, width: 60, height: 34),
        OcrLine(text: 'A UNIDADE', left: 430, top: 335, width: 220, height: 24),
        OcrLine(text: 'UNIDADES', left: 165, top: 357, width: 110, height: 10),
        OcrLine(text: 'CXA 10,74', left: 70, top: 400, width: 120, height: 12),
        OcrLine(text: 'Preço por L', left: 70, top: 450, width: 80, height: 12),
        OcrLine(text: 'Atacado 3,58', left: 70, top: 470, width: 120, height: 12),
        OcrLine(text: 'Varejo 3,58', left: 70, top: 490, width: 120, height: 12),
      ]);

      expect(reading.offers, const [
        PriceOffer(price: Money.cents(179), condition: LoyaltyMembers()),
        PriceOffer(price: Money.cents(179), condition: Wholesale(minimumQuantity: 6)),
      ]);
      expect(reading.price, const Money.cents(179));
      expect(reading.productNameHint, 'Det Liq Minuano 500ml Coco');
    });

    test('atacado sem quantidade legível fica com o mínimo desconhecido', () {
      final reading = parser.parse(const [
        OcrLine(text: 'LIMP VEJA PERF 2L LAVANDA DA FRANCA', left: 125, top: 60, width: 520, height: 40),
        OcrLine(text: 'ATACADO R\$', left: 135, top: 175, width: 110, height: 16),
        OcrLine(text: '13.89', left: 135, top: 215, width: 110, height: 50),
        OcrLine(text: 'PASSAI CRED R\$', left: 285, top: 255, width: 140, height: 16),
        OcrLine(text: '13.89', left: 300, top: 300, width: 115, height: 55),
        OcrLine(text: 'A PARTIR DE', left: 140, top: 300, width: 90, height: 10),
        OcrLine(text: 'VAREJO R\$', left: 490, top: 375, width: 90, height: 14),
        OcrLine(text: '15.35', left: 485, top: 400, width: 115, height: 52),
        OcrLine(text: 'À UNIDADE', left: 300, top: 420, width: 100, height: 14),
        OcrLine(text: 'À UNIDADE', left: 470, top: 530, width: 100, height: 12),
      ]);

      expect(reading.offers, const [
        PriceOffer(price: Money.cents(1535), condition: AnyCustomer()),
        PriceOffer(price: Money.cents(1389), condition: LoyaltyMembers()),
        PriceOffer(price: Money.cents(1389), condition: Wholesale()),
      ]);
      expect(reading.price, const Money.cents(1535));
      expect(reading.productNameHint, 'Limp Veja Perf 2l Lavanda Da Franca');
    });

    test('"Preço Por Unidade" acima do preço não o torna preço por medida', () {
      final reading = parser.parse(const [
        OcrLine(text: 'BATATA PALHA YOKI EXTRA FINA 100g TRAD', left: 15, top: 10, width: 280, height: 12),
        OcrLine(text: 'Preço Por Unidade', left: 30, top: 35, width: 120, height: 14),
        OcrLine(text: 'R\$', left: 25, top: 85, width: 14, height: 10),
        OcrLine(text: '5,99', left: 75, top: 70, width: 75, height: 30),
      ]);

      expect(reading.offers, const [
        PriceOffer(price: Money.cents(599), condition: AnyCustomer()),
      ]);
      expect(reading.price, const Money.cents(599));
      expect(reading.productNameHint, 'Batata Palha Yoki Extra Fina 100g Trad');
    });

    test('cartaz de oferta com o nome em várias linhas', () {
      final reading = parser.parse(const [
        OcrLine(text: 'OFERTA', left: 250, top: 30, width: 90, height: 18),
        OcrLine(text: 'LAVA ROUPA LIQ', left: 240, top: 75, width: 110, height: 12),
        OcrLine(text: 'ASSAI', left: 240, top: 90, width: 50, height: 12),
        OcrLine(text: 'BLOOM 3L', left: 240, top: 105, width: 70, height: 12),
        OcrLine(text: '24,89', left: 230, top: 120, width: 130, height: 40),
      ]);

      expect(reading.offers, const [
        PriceOffer(price: Money.cents(2489), condition: AnyCustomer()),
      ]);
      expect(reading.price, const Money.cents(2489));
      expect(reading.productNameHint, 'Lava Roupa Liq');
    });

    test('cartaz de oferta sem R\$', () {
      final reading = parser.parse(const [
        OcrLine(text: 'OFERTA', left: 90, top: 70, width: 110, height: 20),
        OcrLine(text: 'FRALDA HUGGIES MAX PROT', left: 55, top: 125, width: 160, height: 12),
        OcrLine(text: '59,90', left: 80, top: 145, width: 105, height: 34),
      ]);

      expect(reading.offers, const [
        PriceOffer(price: Money.cents(5990), condition: AnyCustomer()),
      ]);
      expect(reading.price, const Money.cents(5990));
      expect(reading.productNameHint, 'Fralda Huggies Max Prot');
    });
  });

  test('etiqueta sem preço nem código é vazia', () {
    final reading = parser.parse(tag([('PAO FRANCES', 20)]));

    expect(reading.price, isNull);
    expect(reading.isEmpty, isTrue);
    expect(reading.productNameHint, 'Pao Frances');
  });
}
