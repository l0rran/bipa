import 'package:bipa/features/shopping_list/domain/shopping_list_item.dart';

/// Acesso à lista de compras.
abstract interface class ShoppingListRepository {
  /// Itens da lista, na ordem em que entraram.
  Stream<List<ShoppingListEntry>> watchAll();

  /// Põe o produto na lista, com [quantity] embalagens. Se ele já está, não
  /// duplica: só volta a faltar, com a quantidade nova, caso estivesse
  /// marcado como comprado.
  Future<void> addProduct({required String productId, required String name, int quantity = 1});

  /// Põe na lista um item escrito à mão.
  Future<void> addCustom(String name);

  Future<void> setChecked(String itemId, {required bool checked});

  /// Muda quantas embalagens comprar; pelo menos 1.
  Future<void> setQuantity(String itemId, int quantity);

  /// Marca como comprado o produto, se ele está na lista e ainda falta. É o
  /// que acontece quando a pessoa registra o preço dele durante a compra.
  Future<void> checkProduct(String productId);

  /// Volta a deixar o produto como faltando (por exemplo, quando ele sai do
  /// carrinho com o "levar" desligado).
  Future<void> uncheckProduct(String productId);

  Future<void> remove(String itemId);

  /// Tira o produto da lista, esteja ele comprado ou não.
  Future<void> removeProduct(String productId);

  /// Tira da lista o que já foi comprado.
  Future<void> removeChecked();

  /// Devolve à lista um item removido (o "Desfazer").
  Future<void> restore(ShoppingListItem item);
}
