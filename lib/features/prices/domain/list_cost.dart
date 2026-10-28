import 'package:bipa/core/money/money.dart';
import 'package:bipa/features/prices/domain/price_comparison.dart';
import 'package:bipa/features/prices/domain/price_observation.dart';
import 'package:bipa/features/products/domain/product_package.dart';
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
/// sem condição na frente (ADR 0011), na embalagem de referência
/// ([referencePricesPerMarket]), vezes a quantidade de cada um na lista
/// ([quantities]; 1 quando não informada).
///
/// Vêm primeiro os mercados com preço de mais produtos e, entre eles, o mais
/// barato: um mercado com metade da lista não parece o mais barato só por
/// faltar preço.
List<MarketListCost> listCostPerMarket(
  Set<String> productIds,
  Iterable<PriceHistoryEntry> history, {
  Map<String, ProductPackage> packages = const {},
  Map<String, int> quantities = const {},
}) {
  final perMarket = referencePricesPerMarket(productIds, history, packages: packages);
  return [
    for (final MapEntry(key: marketId, value: (:marketName, :byProduct)) in perMarket.entries)
      MarketListCost(
        marketId: marketId,
        marketName: marketName,
        total: byProduct.entries.fold(Money.zero, (sum, entry) => sum + entry.value * (quantities[entry.key] ?? 1)),
        priced: byProduct.length,
        items: productIds.length,
      ),
  ]..sort((a, b) {
    final byPriced = b.priced.compareTo(a.priced);
    if (byPriced != 0) return byPriced;
    final byTotal = a.total.compareTo(b.total);
    return byTotal != 0 ? byTotal : a.marketName.compareTo(b.marketName);
  });
}

/// Os preços de um mercado: o nome dele e o preço de cada produto que tem
/// preço lá.
typedef MarketPrices = ({String marketName, Map<String, Money> byProduct});

/// O preço mais recente de cada um dos [productIds] em cada mercado, sem
/// condição na frente (ADR 0011), por id do mercado.
///
/// Embalagens diferentes se comparam pelo preço por kg (ADR 0013): cada
/// produto conta na embalagem do preço mais recente dele (a de referência),
/// e o preço de outra embalagem vale o preço por kg dela vezes o tamanho da
/// de referência. Sem tamanho para converter, o mercado fica sem preço
/// daquele produto.
///
/// Com [references], a embalagem de referência de um produto é a dada (a
/// que foi para o carrinho, por exemplo), não a do preço mais recente.
Map<String, MarketPrices> referencePricesPerMarket(
  Set<String> productIds,
  Iterable<PriceHistoryEntry> history, {
  Map<String, ProductPackage> packages = const {},
  Map<String, String?> references = const {},
}) {
  if (productIds.isEmpty) return const {};
  final historyByProduct = <String, List<PriceHistoryEntry>>{};
  for (final entry in history) {
    final productId = entry.observation.productId;
    if (productIds.contains(productId)) historyByProduct.putIfAbsent(productId, () => []).add(entry);
  }

  final prices = <String, Map<String, Money>>{};
  final names = <String, String>{};
  for (final MapEntry(key: productId, value: entries) in historyByProduct.entries) {
    final latestAnywhere = entries.reduce((a, b) => b.observation.observedAt.isAfter(a.observation.observedAt) ? b : a);
    final referenceId = references.containsKey(productId)
        ? references[productId]
        : latestAnywhere.observation.packageId;
    for (final latest in latestPricePerMarket(entries)) {
      final price = _inReferencePackage(latest.observation, referenceId, packages);
      if (price == null) continue;
      final marketId = latest.observation.marketId;
      prices.putIfAbsent(marketId, () => {})[productId] = price;
      names[marketId] = latest.marketName;
    }
  }
  return {
    for (final MapEntry(key: marketId, value: byProduct) in prices.entries)
      marketId: (marketName: names[marketId]!, byProduct: byProduct),
  };
}

/// O preço de [observation] na embalagem de referência: o próprio, se for
/// ela; senão, o preço por kg vezes o tamanho dela, se der para converter.
Money? _inReferencePackage(PriceObservation observation, String? referenceId, Map<String, ProductPackage> packages) {
  if (observation.packageId == referenceId) return observation.price;
  final reference = packages[referenceId];
  final size = reference?.sizeInBaseUnit;
  final unitPrice = packages[observation.packageId]?.unitPrice(observation.price);
  if (reference == null || size == null || unitPrice == null || unitPrice.unit != reference.unit.baseUnit) {
    return null;
  }
  return Money.cents((unitPrice.price.cents * size).round());
}
