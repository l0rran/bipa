import 'package:bipa/core/money/money.dart';
import 'package:bipa/features/prices/domain/list_cost.dart';
import 'package:bipa/features/prices/domain/price_condition.dart';
import 'package:bipa/features/prices/domain/price_observation.dart';
import 'package:bipa/features/prices/domain/price_source.dart';
import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:bipa/features/products/domain/product_package.dart';
import 'package:flutter_test/flutter_test.dart';

var _seq = 0;

PriceHistoryEntry _price(
  String market,
  String product,
  int cents, {
  int day = 1,
  PriceCondition condition = const AnyCustomer(),
  String? package,
}) => PriceHistoryEntry(
  observation: PriceObservation(
    id: 'o${_seq++}',
    productId: product,
    packageId: package,
    marketId: market,
    price: Money.cents(cents),
    source: PriceSource.priceTag,
    condition: condition,
    observedAt: DateTime(2026, 10, day),
    createdAt: DateTime(2026, 10, day),
  ),
  marketName: market,
);

void main() {
  test('soma a lista em cada mercado com o preço mais recente, do mais barato ao mais caro', () {
    final costs = listCostPerMarket(
      {'arroz', 'cafe'},
      [
        _price('vila', 'arroz', 2790),
        _price('vila', 'cafe', 1899),
        _price('centro', 'arroz', 2990, day: 1),
        _price('centro', 'arroz', 2590, day: 5),
        _price('centro', 'cafe', 1999),
        _price('centro', 'leite', 479), // fora da lista
      ],
    );

    expect(costs.map((c) => (c.marketId, c.total.cents)), [('centro', 4589), ('vila', 4689)]);
    expect(costs.every((c) => !c.isPartial), isTrue);
  });

  test('um mercado com menos preços vem depois, mesmo que some menos', () {
    final costs = listCostPerMarket(
      {'arroz', 'cafe'},
      [_price('vila', 'arroz', 2790), _price('vila', 'cafe', 1899), _price('bairro', 'arroz', 2490)],
    );

    expect(costs.map((c) => c.marketId), ['vila', 'bairro']);
    expect((costs.last.priced, costs.last.items, costs.last.isPartial), (1, 2, true));
  });

  test('o preço com cartão só vale quando não há preço de varejo', () {
    final costs = listCostPerMarket(
      {'arroz'},
      [_price('vila', 'arroz', 2790), _price('vila', 'arroz', 2490, condition: const LoyaltyMembers())],
    );

    expect(costs.single.total.cents, 2790);
  });

  test('embalagens diferentes se comparam pelo preço por kg, na embalagem de referência', () {
    final now = DateTime(2026, 10, 28);
    ProductPackage kilos(String id, double size) => ProductPackage(
      id: id,
      productId: 'arroz',
      size: size,
      unit: MeasureUnit.kilogram,
      createdAt: now,
      updatedAt: now,
    );
    final costs = listCostPerMarket(
      {'arroz'},
      [
        _price('vila', 'arroz', 2790, package: 'cinco', day: 5), // a mais recente: referência de 5 kg
        _price('centro', 'arroz', 4990, package: 'dez', day: 1), // R$ 4,99/kg → R$ 24,95 em 5 kg
      ],
      packages: {'cinco': kilos('cinco', 5), 'dez': kilos('dez', 10)},
    );

    expect(costs.map((c) => (c.marketId, c.total.cents)), [('centro', 2495), ('vila', 2790)]);
  });

  test('sem tamanho para converter, o mercado fica sem preço do produto', () {
    final costs = listCostPerMarket(
      {'arroz'},
      [_price('vila', 'arroz', 2790, package: 'a', day: 5), _price('centro', 'arroz', 4990, package: 'b', day: 1)],
    );

    expect(costs.map((c) => c.marketId), ['vila']);
  });

  test('a quantidade da lista multiplica o preço de cada produto', () {
    final costs = listCostPerMarket(
      {'leite', 'cafe'},
      [_price('vila', 'leite', 499), _price('vila', 'cafe', 1899)],
      quantities: {'leite': 3},
    );

    expect(costs.single.total, const Money.cents(499 * 3 + 1899));
  });

  test('com a embalagem de referência dada, os outros preços são convertidos para ela', () {
    final packages = {
      'arroz-5': ProductPackage(
        id: 'arroz-5',
        productId: 'arroz',
        size: 5,
        unit: MeasureUnit.kilogram,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
      'arroz-1': ProductPackage(
        id: 'arroz-1',
        productId: 'arroz',
        size: 1,
        unit: MeasureUnit.kilogram,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    };
    final history = [
      _price('vila', 'arroz', 2500, package: 'arroz-5'),
      // O mais recente é o de 1 kg, mas o carrinho levou o de 5 kg.
      _price('centro', 'arroz', 600, day: 9, package: 'arroz-1'),
    ];

    final prices = referencePricesPerMarket({'arroz'}, history, packages: packages, references: {'arroz': 'arroz-5'});

    expect(prices['vila']?.byProduct, {'arroz': const Money.cents(2500)});
    expect(prices['centro']?.byProduct, {'arroz': const Money.cents(3000)});
  });

  test('os preços de cada produto em cada mercado, com o nome do mercado', () {
    final prices = referencePricesPerMarket(
      {'arroz', 'cafe'},
      [_price('vila', 'arroz', 2790), _price('vila', 'cafe', 1899), _price('centro', 'arroz', 2590)],
    );

    // Mapas dentro de um record não se comparam por conteúdo: um campo de cada vez.
    expect(prices['vila']?.marketName, 'vila');
    expect(prices['vila']?.byProduct, {'arroz': const Money.cents(2790), 'cafe': const Money.cents(1899)});
    expect(prices['centro']?.byProduct, {'arroz': const Money.cents(2590)});
  });

  group('mais barato numa comparação justa', () {
    test('com a lista inteira e mais barato também na cesta em comum', () {
      final comparison = compareListCost(
        {'arroz', 'cafe'},
        [
          _price('vila', 'arroz', 2790),
          _price('vila', 'cafe', 1899),
          _price('centro', 'arroz', 2990),
          _price('centro', 'cafe', 1999),
          // Só o arroz, e mais caro que na Vila.
          _price('bairro', 'arroz', 2890),
        ],
      );

      expect(comparison.markets.map((c) => c.marketId), ['vila', 'centro', 'bairro']);
      expect(comparison.cheapestId, 'vila');
    });

    test('sem selo quando um mercado com menos preços é mais barato no que tem', () {
      final comparison = compareListCost(
        {'arroz', 'cafe'},
        [
          _price('vila', 'arroz', 2790),
          _price('vila', 'cafe', 1899),
          // O arroz sai mais barato aqui; sem o café, não dá para saber o total.
          _price('bairro', 'arroz', 2490),
        ],
      );

      expect(comparison.markets.first.marketId, 'vila');
      expect(comparison.cheapestId, isNull);
    });

    test('sem selo quando nenhum mercado tem a lista inteira, ou há um só', () {
      expect(
        compareListCost({'arroz', 'cafe'}, [_price('vila', 'arroz', 2790), _price('centro', 'cafe', 1899)]).cheapestId,
        isNull,
      );
      expect(compareListCost({'arroz'}, [_price('vila', 'arroz', 2790)]).cheapestId, isNull);
    });

    test('sem selo num empate', () {
      final comparison = compareListCost(
        {'arroz'},
        [_price('vila', 'arroz', 2790), _price('centro', 'arroz', 2790)],
      );

      expect(comparison.cheapestId, isNull);
    });

    test('a cesta em comum conta as quantidades da lista', () {
      final comparison = compareListCost(
        {'leite', 'cafe'},
        [
          _price('vila', 'leite', 499),
          _price('vila', 'cafe', 1899),
          // O leite sai mais barato aqui, e são 3 leites na lista.
          _price('bairro', 'leite', 459),
        ],
        quantities: {'leite': 3},
      );

      expect(comparison.cheapestId, isNull);
    });
  });

  test('cada mercado guarda a data do preço mais antigo que entrou no total', () {
    final costs = listCostPerMarket(
      {'arroz', 'cafe'},
      [
        _price('vila', 'arroz', 2790, day: 3),
        _price('vila', 'cafe', 1899, day: 20),
        // O mais antigo do café foi substituído pelo de dia 20: não conta.
        _price('vila', 'cafe', 1799, day: 1),
      ],
    );

    expect(costs.single.oldest, DateTime(2026, 10, 3));
  });

  test('sem lista, não há o que comparar', () {
    expect(listCostPerMarket(const {}, [_price('vila', 'arroz', 2790)]), isEmpty);
  });
}
