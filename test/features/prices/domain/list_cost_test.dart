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
    final costs = listCostPerMarket({'arroz', 'cafe'}, [
      _price('vila', 'arroz', 2790),
      _price('vila', 'cafe', 1899),
      _price('centro', 'arroz', 2990, day: 1),
      _price('centro', 'arroz', 2590, day: 5),
      _price('centro', 'cafe', 1999),
      _price('centro', 'leite', 479), // fora da lista
    ]);

    expect(costs.map((c) => (c.marketId, c.total.cents)), [('centro', 4589), ('vila', 4689)]);
    expect(costs.every((c) => !c.isPartial), isTrue);
  });

  test('um mercado com menos preços vem depois, mesmo que some menos', () {
    final costs = listCostPerMarket({'arroz', 'cafe'}, [
      _price('vila', 'arroz', 2790),
      _price('vila', 'cafe', 1899),
      _price('bairro', 'arroz', 2490),
    ]);

    expect(costs.map((c) => c.marketId), ['vila', 'bairro']);
    expect((costs.last.priced, costs.last.items, costs.last.isPartial), (1, 2, true));
  });

  test('o preço com cartão só vale quando não há preço de varejo', () {
    final costs = listCostPerMarket({'arroz'}, [
      _price('vila', 'arroz', 2790),
      _price('vila', 'arroz', 2490, condition: const LoyaltyMembers()),
    ]);

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
    final costs = listCostPerMarket({'arroz'}, [
      _price('vila', 'arroz', 2790, package: 'a', day: 5),
      _price('centro', 'arroz', 4990, package: 'b', day: 1),
    ]);

    expect(costs.map((c) => c.marketId), ['vila']);
  });

  test('sem lista, não há o que comparar', () {
    expect(listCostPerMarket(const {}, [_price('vila', 'arroz', 2790)]), isEmpty);
  });
}
