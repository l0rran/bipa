import 'package:bipa/core/money/money.dart';
import 'package:bipa/features/prices/domain/price_comparison.dart';
import 'package:bipa/features/prices/domain/price_observation.dart';
import 'package:meta/meta.dart';

/// Quanto a lista custa num mercado, com os preços mais recentes dele.
@immutable
final class MarketListCost {
  const MarketListCost({
    required this.marketId,
    required this.marketName,
    required this.total,
    required this.priced,
    required this.items,
  });

  final String marketId;
  final String marketName;
  final Money total;

  /// Quantos produtos da lista têm preço nesse mercado, de [items].
  final int priced;
  final int items;

  /// Faltam preços: o total desse mercado não é a lista inteira.
  bool get isPartial => priced < items;

  @override
  bool operator ==(Object other) =>
      other is MarketListCost &&
      other.marketId == marketId &&
      other.marketName == marketName &&
      other.total == total &&
      other.priced == priced &&
      other.items == items;

  @override
  int get hashCode => Object.hash(marketId, marketName, total, priced, items);

  @override
  String toString() => 'MarketListCost($marketName, $total, $priced/$items)';
}

/// A lista (os [productIds] que faltam comprar) somada em cada mercado com
/// preço de pelo menos um deles: o preço mais recente de cada produto ali,
/// sem condição na frente (ADR 0011).
///
/// Vêm primeiro os mercados com preço de mais produtos e, entre eles, o mais
/// barato: um mercado com metade da lista não parece o mais barato só por
/// faltar preço.
List<MarketListCost> listCostPerMarket(Set<String> productIds, Iterable<PriceHistoryEntry> history) {
  if (productIds.isEmpty) return const [];
  final byProduct = <String, List<PriceHistoryEntry>>{};
  for (final entry in history) {
    final productId = entry.observation.productId;
    if (productIds.contains(productId)) byProduct.putIfAbsent(productId, () => []).add(entry);
  }

  final totals = <String, Money>{};
  final priced = <String, int>{};
  final names = <String, String>{};
  for (final entries in byProduct.values) {
    for (final latest in latestPricePerMarket(entries)) {
      final marketId = latest.observation.marketId;
      totals[marketId] = (totals[marketId] ?? Money.zero) + latest.observation.price;
      priced[marketId] = (priced[marketId] ?? 0) + 1;
      names[marketId] = latest.marketName;
    }
  }

  return [
    for (final MapEntry(key: marketId, value: total) in totals.entries)
      MarketListCost(
        marketId: marketId,
        marketName: names[marketId]!,
        total: total,
        priced: priced[marketId]!,
        items: productIds.length,
      ),
  ]..sort((a, b) {
    final byPriced = b.priced.compareTo(a.priced);
    if (byPriced != 0) return byPriced;
    final byTotal = a.total.compareTo(b.total);
    return byTotal != 0 ? byTotal : a.marketName.compareTo(b.marketName);
  });
}
