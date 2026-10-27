import 'package:bipa/core/money/money.dart';
import 'package:bipa/features/prices/domain/price_comparison.dart';
import 'package:bipa/features/prices/domain/price_observation.dart';
import 'package:bipa/features/prices/domain/price_source.dart';
import 'package:flutter_test/flutter_test.dart';

PriceHistoryEntry entry(String market, int cents, DateTime at) => PriceHistoryEntry(
  marketName: market,
  observation: PriceObservation(
    id: '$market-$cents',
    productId: 'leite',
    marketId: market,
    price: Money.cents(cents),
    source: PriceSource.manual,
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

  test('histórico vazio resulta em lista vazia', () {
    expect(latestPricePerMarket(const []), isEmpty);
  });
}
