import 'package:bipa/core/money/money.dart';
import 'package:bipa/features/prices/domain/price_comparison.dart';
import 'package:bipa/features/prices/domain/price_condition.dart';
import 'package:bipa/features/prices/domain/price_observation.dart';
import 'package:bipa/features/prices/domain/price_source.dart';
import 'package:flutter_test/flutter_test.dart';

PriceHistoryEntry entry(
  String market,
  int cents,
  DateTime at, {
  PriceCondition condition = const AnyCustomer(),
}) => PriceHistoryEntry(
  marketName: market,
  observation: PriceObservation(
    id: '$market-$cents-$condition',
    productId: 'leite',
    marketId: market,
    price: Money.cents(cents),
    source: PriceSource.manual,
    condition: condition,
    observedAt: at,
    createdAt: at,
  ),
);

void main() {
  test('mantém só o preço mais recente de cada mercado, do mais barato ao mais caro', () {
    final history = [
      entry('A', 500, DateTime(2026, 10, 1)),
      entry('A', 650, DateTime(2026, 10, 20)),
      entry('B', 600, DateTime(2026, 10, 10)),
      entry('C', 450, DateTime(2026, 9, 1)),
    ];

    final latest = latestPricePerMarket(history);

    expect(latest.map((e) => (e.marketName, e.observation.price.cents)), [
      ('C', 450),
      ('B', 600),
      ('A', 650),
    ]);
  });

  test('compara pelo preço sem condição, mesmo que o de cartão seja mais recente', () {
    final at = DateTime(2026, 10, 27);
    final history = [
      entry('Assaí', 805, at),
      entry('Assaí', 785, at.add(const Duration(minutes: 1)), condition: const LoyaltyMembers()),
      entry('Assaí', 785, at, condition: const Wholesale(minimumQuantity: 10)),
      entry('Bairro', 799, at),
    ];

    final latest = latestPricePerMarket(history);

    expect(latest.map((e) => (e.marketName, e.observation.price.cents)), [('Bairro', 799), ('Assaí', 805)]);
  });

  test('sem preço de varejo, o mercado entra com o preço condicional', () {
    final at = DateTime(2026, 10, 27);
    final history = [
      entry('Assaí', 179, at, condition: const LoyaltyMembers()),
      entry('Bairro', 229, at),
    ];

    expect(latestPricePerMarket(history).map((e) => e.marketName), ['Assaí', 'Bairro']);
  });

  test('cartão e atacado da mesma etiqueta: o de cartão representa o mercado, em qualquer ordem', () {
    final at = DateTime(2026, 10, 27);
    final card = entry('Assaí', 199, at, condition: const LoyaltyMembers());
    final wholesale = entry('Assaí', 179, at, condition: const Wholesale(minimumQuantity: 6));

    expect(latestPricePerMarket([card, wholesale]).single, card);
    expect(latestPricePerMarket([wholesale, card]).single, card);
  });

  test('preço de referência: o menor entre os mais recentes de cada mercado, por produto', () {
    final at = DateTime(2026, 10, 27);
    final history = [
      entry('A', 500, at),
      entry('A', 650, at.add(const Duration(days: 1))),
      entry('B', 600, at),
      entry('Assaí', 480, at, condition: const LoyaltyMembers()),
      entry('Assaí', 520, at),
    ];

    expect(listPrices(history), {'leite': (price: const Money.cents(520), exact: false)});
    expect(listPrices(const []), isEmpty);
  });

  test('preço mais recente num mercado, ou nada se ele nunca foi visto lá', () {
    final at = DateTime(2026, 10, 27);
    final history = [entry('A', 500, at), entry('A', 650, at.add(const Duration(days: 1))), entry('B', 600, at)];

    expect(latestPriceAt(history, 'A'), const Money.cents(650));
    expect(latestPriceAt(history, 'C'), isNull);
  });

  test('na lista, o preço do mercado da compra é exato; o dos outros, estimado', () {
    final at = DateTime(2026, 10, 27);
    final history = [entry('A', 650, at), entry('B', 520, at)];

    expect(listPrices(history, marketId: 'A'), {'leite': (price: const Money.cents(650), exact: true)});
    expect(listPrices(history, marketId: 'C'), {'leite': (price: const Money.cents(520), exact: false)});
    expect(listPrices(history), {'leite': (price: const Money.cents(520), exact: false)});
  });

  test('histórico vazio resulta em lista vazia', () {
    expect(latestPricePerMarket(const []), isEmpty);
  });
}
