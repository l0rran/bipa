import 'package:bipa/core/money/money.dart';
import 'package:bipa/features/prices/domain/list_cost.dart';
import 'package:bipa/features/shopping_list/domain/cart_item.dart';
import 'package:bipa/features/shopping_list/domain/shopping_list_item.dart';
import 'package:meta/meta.dart';

/// Quanto a compra saiu mais barata que no mercado mais barato depois deste.
typedef TripSavings = ({String marketName, Money amount});

/// O que o "Terminei" vai fazer, mostrado antes de confirmar (folha "Fim da
/// compra"): o total, quantas embalagens vão para casa, a economia contra
/// outro mercado e o que faltou da lista.
@immutable
final class TripReview {
  const TripReview({
    required this.packages,
    required this.missing,
    this.spent,
    this.estimated = false,
    this.unpriced = 0,
    this.savings,
  });

  /// Monta a revisão com a lista, o carrinho e os preços dos produtos da
  /// compra em cada mercado ([referencePricesPerMarket]).
  ///
  /// A economia só aparece quando este mercado e outro têm preço de tudo o
  /// que vai para casa, e este saiu mais barato: comparar cestas diferentes
  /// enganaria.
  factory TripReview.of({
    required Iterable<ShoppingListEntry> entries,
    required Iterable<CartEntry> cart,
    String? marketId,
    Map<String, MarketPrices> prices = const {},
  }) {
    Money? spent;
    var estimated = false;
    var unpriced = 0;
    var packages = 0;
    // Quantas embalagens de cada produto vão para casa, como no "Terminei".
    final quantities = <String, int>{};
    for (final entry in cart) {
      if (!entry.item.take) continue;
      packages += entry.item.quantity;
      quantities.update(entry.item.productId, (q) => q + entry.item.quantity, ifAbsent: () => entry.item.quantity);
      final subtotal = entry.item.subtotal;
      if (subtotal == null) {
        unpriced++;
        continue;
      }
      spent = (spent ?? Money.zero) + subtotal;
      if (entry.item.priceEstimated) estimated = true;
    }
    final inCart = {for (final entry in cart) entry.item.productId};
    final missing = <String>[];
    for (final entry in entries) {
      final item = entry.item;
      if (!item.isChecked) {
        missing.add(entry.name);
      } else if (item.productId case final productId? when !inCart.contains(productId)) {
        // Marcado à mão, sem passar pelo carrinho: vai com a quantidade da lista.
        quantities[productId] = item.quantity;
        packages += item.quantity;
      }
    }

    return TripReview(
      packages: packages,
      missing: missing,
      spent: spent,
      estimated: estimated,
      unpriced: unpriced,
      savings: _savings(quantities, marketId, prices),
    );
  }

  /// Embalagens que vão para casa: as do carrinho para levar e as marcadas
  /// à mão na lista.
  final int packages;

  /// O que faltou da lista; continua nela depois do "Terminei".
  final List<String> missing;

  /// O total do carrinho; `null` sem nenhum preço.
  final Money? spent;

  /// Algum preço do total ainda é o do histórico.
  final bool estimated;

  /// Itens do carrinho sem preço, fora do total.
  final int unpriced;

  final TripSavings? savings;

  static TripSavings? _savings(Map<String, int> quantities, String? marketId, Map<String, MarketPrices> prices) {
    if (marketId == null || quantities.isEmpty) return null;
    Money? basketAt(MarketPrices market) {
      var total = Money.zero;
      for (final MapEntry(key: productId, value: quantity) in quantities.entries) {
        final price = market.byProduct[productId];
        if (price == null) return null;
        total += price * quantity;
      }
      return total;
    }

    final here = switch (prices[marketId]) {
      final market? => basketAt(market),
      null => null,
    };
    if (here == null) return null;
    TripSavings? cheapestOther;
    for (final MapEntry(key: otherId, value: market) in prices.entries) {
      if (otherId == marketId) continue;
      final total = basketAt(market);
      if (total != null && (cheapestOther == null || total < cheapestOther.amount)) {
        cheapestOther = (marketName: market.marketName, amount: total);
      }
    }
    if (cheapestOther == null || cheapestOther.amount <= here) return null;
    return (marketName: cheapestOther.marketName, amount: cheapestOther.amount - here);
  }

  @override
  bool operator ==(Object other) =>
      other is TripReview &&
      other.packages == packages &&
      _sameList(other.missing, missing) &&
      other.spent == spent &&
      other.estimated == estimated &&
      other.unpriced == unpriced &&
      other.savings == savings;

  static bool _sameList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(packages, Object.hashAll(missing), spent, estimated, unpriced, savings);

  @override
  String toString() => 'TripReview($packages emb., ${spent?.format()}, faltaram ${missing.length}, $savings)';
}
