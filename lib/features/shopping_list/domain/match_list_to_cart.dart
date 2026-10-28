import 'package:bipa/features/shopping_list/domain/cart_item.dart';
import 'package:bipa/features/shopping_list/domain/shopping_list_repository.dart';

/// O que mudou antes de acertar a lista com o carrinho.
enum CartListChange {
  /// Entrou algo no carrinho: o bipe, o preço lido, o "levar" ligado ou uma
  /// quantidade maior.
  added,

  /// Saiu algo do carrinho: o "levar" desligado ou uma quantidade menor.
  removed,

  /// A quantidade da lista mudou durante a compra.
  listQuantity,
}

/// Caso de uso: deixa o produto marcado na lista quando o carrinho alcança
/// a quantidade dela. Com "3× Leite" e uma caixa bipada, o item continua
/// faltando ("1 de 3"); com a terceira, fica marcado (CE3).
///
/// O que entra no carrinho só marca, nunca desmarca: quem marcou à mão (na
/// compra ou antes dela) já disse que levou. O que sai do carrinho desmarca
/// quando ele fica abaixo da lista, e mudar a quantidade da lista acerta a
/// marcação pelo que já está no carrinho.
final class MatchListToCart {
  const MatchListToCart({required ShoppingListRepository list, required CartRepository cart})
    : _list = list,
      _cart = cart;

  final ShoppingListRepository _list;
  final CartRepository _cart;

  Future<void> call(String tripId, String productId, CartListChange change) async {
    final item = [
      for (final entry in await _list.watchAll().first)
        if (entry.item.productId == productId) entry.item,
    ].firstOrNull;
    if (item == null) return;
    final taken = CartEntry.takenByProduct(await _cart.watchTrip(tripId).first)[productId] ?? 0;
    final complete = item.missingWith(taken) == 0;
    final checked = switch (change) {
      CartListChange.added => item.isChecked || complete,
      CartListChange.removed => item.isChecked && complete,
      // Sem nada no carrinho, a lista não diz nada sobre o que foi marcado à mão.
      CartListChange.listQuantity => taken == 0 ? item.isChecked : complete,
    };
    if (checked != item.isChecked) await _list.setChecked(item.id, checked: checked);
  }
}
