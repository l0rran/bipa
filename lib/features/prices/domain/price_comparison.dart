import 'package:bipa/features/prices/domain/price_observation.dart';

/// Mantém apenas a observação mais recente de cada mercado, ordenadas do
/// menor para o maior preço. O primeiro item é onde o produto está mais barato.
List<PriceHistoryEntry> latestPricePerMarket(Iterable<PriceHistoryEntry> history) {
  final latest = <String, PriceHistoryEntry>{};
  for (final entry in history) {
    final marketId = entry.observation.marketId;
    final current = latest[marketId];
    if (current == null || entry.observation.observedAt.isAfter(current.observation.observedAt)) {
      latest[marketId] = entry;
    }
  }
  return latest.values.toList()
    ..sort((a, b) => a.observation.price.compareTo(b.observation.price));
}
