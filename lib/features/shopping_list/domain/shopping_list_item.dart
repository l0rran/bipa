import 'package:bipa/features/products/domain/product.dart';
import 'package:meta/meta.dart';

/// Um item da lista de compras: um produto cadastrado ou algo escrito à mão
/// ("pão", "pilhas"). A lista é privada e nunca é sincronizada (ADR 0007).
@immutable
final class ShoppingListItem {
  const ShoppingListItem({
    required this.id,
    required this.name,
    required this.addedAt,
    this.productId,
    this.checkedAt,
  });

  final String id;

  /// Produto cadastrado; `null` para itens escritos à mão.
  final String? productId;

  /// Nome no momento em que o item entrou na lista.
  final String name;
  final DateTime addedAt;

  /// Quando o item foi marcado como comprado; `null` enquanto falta.
  final DateTime? checkedAt;

  bool get isChecked => checkedAt != null;

  @override
  bool operator ==(Object other) =>
      other is ShoppingListItem &&
      other.id == id &&
      other.productId == productId &&
      other.name == name &&
      other.addedAt == addedAt &&
      other.checkedAt == checkedAt;

  @override
  int get hashCode => Object.hash(id, productId, name, addedAt, checkedAt);

  @override
  String toString() => 'ShoppingListItem($name${isChecked ? ', comprado' : ''})';
}

/// Item da lista com o produto, quando ele é cadastrado.
@immutable
final class ShoppingListEntry {
  const ShoppingListEntry({required this.item, this.product});

  final ShoppingListItem item;
  final Product? product;

  /// O nome atual do produto, ou o que foi escrito.
  String get name => product?.name ?? item.name;

  @override
  bool operator ==(Object other) => other is ShoppingListEntry && other.item == item && other.product == product;

  @override
  int get hashCode => Object.hash(item, product);
}
