import 'package:bipa/core/money/money.dart';
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
    if (current == null || _isPreferred(entry.observation, current.observation)) {
      target[marketId] = entry;
    }
  }
  final latest = {...latestConditional, ...latestAnyCustomer};
  return latest.values.toList()..sort((a, b) => a.observation.price.compareTo(b.observation.price));
}

/// A mais recente vence. Preços da mesma etiqueta têm o mesmo horário: aí vale
/// a ordem das condições (cartão antes de atacado), para o resultado não
/// depender da ordem em que o banco devolve as linhas.
bool _isPreferred(PriceObservation candidate, PriceObservation current) {
  final byTime = candidate.observedAt.compareTo(current.observedAt);
  if (byTime != 0) return byTime > 0;
  final byCondition = candidate.condition.kind.index.compareTo(current.condition.kind.index);
  if (byCondition != 0) return byCondition < 0;
  return candidate.price < current.price;
}

/// O preço de um item da lista: o do mercado da compra, quando o produto já
/// foi visto lá ([exact]), ou o de referência dos outros mercados, que é só
/// uma estimativa.
typedef ListPrice = ({Money price, bool exact});

/// O preço de cada produto do histórico para a lista de compras. Com
/// [marketId], o preço daquele mercado vale mais que o de referência.
Map<String, ListPrice> listPrices(Iterable<PriceHistoryEntry> history, {String? marketId}) => {
  for (final MapEntry(key: productId, value: entries) in _byProduct(history).entries)
    productId: switch (marketId == null ? null : latestPriceAt(entries, marketId)) {
      final here? => (price: here, exact: true),
      // O de referência: o menor entre os preços mais recentes de cada
      // mercado, com o preço sem condição na frente.
      null => (price: latestPricePerMarket(entries).first.observation.price, exact: false),
    },
};

Map<String, List<PriceHistoryEntry>> _byProduct(Iterable<PriceHistoryEntry> history) {
  final byProduct = <String, List<PriceHistoryEntry>>{};
  for (final entry in history) {
    byProduct.putIfAbsent(entry.observation.productId, () => []).add(entry);
  }
  return byProduct;
}

/// O preço mais recente do produto num mercado (o sem condição na frente),
/// ou `null` se ele nunca foi visto lá. É o preço esperado no modo carrinho.
/// Com [packageId], só vale o preço dessa embalagem (ADR 0013): o arroz de
/// 10 kg não diz quanto custa o de 5 kg.
Money? latestPriceAt(Iterable<PriceHistoryEntry> history, String marketId, {String? packageId}) =>
    latestPricePerMarket([
      for (final entry in history)
        if (packageId == null || entry.observation.packageId == packageId) entry,
    ]).where((entry) => entry.observation.marketId == marketId).firstOrNull?.observation.price;
