import 'package:bipa/features/shopping_list/domain/cart_item.dart';
import 'package:bipa/features/shopping_list/domain/shopping_list_repository.dart';

/// Caso de uso: deixa o produto marcado na lista só quando o carrinho
/// alcança a quantidade dela. Com "3× Leite" e uma caixa bipada, o item
/// continua faltando ("1 de 3"); com a terceira, fica marcado. Desligar o
/// "levar" ou baixar a quantidade no carrinho volta a deixá-lo faltando.
///
/// É chamado depois de cada mudança do carrinho que mexe no produto: o
/// bipe, o preço lido, o "levar" e a quantidade.
final class MatchListToCart {
  const MatchListToCart({required ShoppingListRepository list, required CartRepository cart})
    : _list = list,
      _cart = cart;

  final ShoppingListRepository _list;
  final CartRepository _cart;

  Future<void> call(String tripId, String productId) async {
    final item = [
      for (final entry in await _list.watchAll().first)
        if (entry.item.productId == productId) entry.item,
    ].firstOrNull;
    if (item == null) return;
    final taken = CartEntry.takenByProduct(await _cart.watchTrip(tripId).first)[productId] ?? 0;
    final complete = item.missingWith(taken) == 0;
    if (complete != item.isChecked) await _list.setChecked(item.id, checked: complete);
  }
}
