import 'package:bipa/core/money/money.dart';
import 'package:bipa/features/prices/domain/list_cost.dart';
import 'package:bipa/features/prices/domain/price_condition.dart';
import 'package:bipa/features/prices/domain/price_observation.dart';
import 'package:bipa/features/prices/domain/price_source.dart';
import 'package:flutter_test/flutter_test.dart';

var _seq = 0;

PriceHistoryEntry _price(
  String market,
  String product,
  int cents, {
  int day = 1,
  PriceCondition condition = const AnyCustomer(),
}) => PriceHistoryEntry(
  observation: PriceObservation(
    id: 'o${_seq++}',
    productId: product,
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

  test('sem lista, não há o que comparar', () {
    expect(listCostPerMarket(const {}, [_price('vila', 'arroz', 2790)]), isEmpty);
  });
}
