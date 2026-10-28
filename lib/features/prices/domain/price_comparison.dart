import 'package:bipa/features/prices/domain/price_condition.dart';
import 'package:bipa/features/prices/domain/price_observation.dart';

/// Mantém apenas a observação mais recente de cada mercado, ordenadas do
/// menor para o maior preço. O primeiro item é onde o produto está mais barato.
///
/// A comparação usa o preço sem condição (ADR 0011): o de cartão ou de atacado
/// só representa um mercado quando não há preço de varejo registrado nele.
List<PriceHistoryEntry> latestPricePerMarket(Iterable<PriceHistoryEntry> history) {
  final latestAnyCustomer = <String, PriceHistoryEntry>{};
  final latestConditional = <String, PriceHistoryEntry>{};
  for (final entry in history) {
    final target = entry.observation.condition is AnyCustomer ? latestAnyCustomer : latestConditional;
    final marketId = entry.observation.marketId;
    final current = target[marketId];
    if (current == null || entry.observation.observedAt.isAfter(current.observation.observedAt)) {
      target[marketId] = entry;
    }
  }
  final latest = {...latestConditional, ...latestAnyCustomer};
  return latest.values.toList()
    ..sort((a, b) => a.observation.price.compareTo(b.observation.price));
}
