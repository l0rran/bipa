import 'package:bipa/features/shopping_list/domain/shopping_list_item.dart';

/// Acesso à lista de compras.
abstract interface class ShoppingListRepository {
  /// Itens da lista, na ordem em que entraram.
  Stream<List<ShoppingListEntry>> watchAll();

  /// Põe o produto na lista. Se ele já está, não duplica: só volta a faltar,
  /// caso estivesse marcado como comprado.
  Future<void> addProduct({required String productId, required String name});

  /// Põe na lista um item escrito à mão.
  Future<void> addCustom(String name);

  Future<void> setChecked(String itemId, {required bool checked});

  /// Marca como comprado o produto, se ele está na lista e ainda falta. É o
  /// que acontece quando a pessoa registra o preço dele durante a compra.
  Future<void> checkProduct(String productId);

  Future<void> remove(String itemId);

  /// Tira o produto da lista, esteja ele comprado ou não.
  Future<void> removeProduct(String productId);

  /// Tira da lista o que já foi comprado.
  Future<void> removeChecked();

  /// Devolve à lista um item removido (o "Desfazer").
  Future<void> restore(ShoppingListItem item);
}
