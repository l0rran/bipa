import 'package:bipa/core/money/money.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:meta/meta.dart';

/// Um produto no carrinho da compra em andamento (o modo carrinho).
///
/// Bipar o mesmo produto de novo soma uma unidade. Com [take] desligado, o
/// preço fica registrado para comparação, mas o item não entra no total nem
/// no estoque.
@immutable
final class CartItem {
  const CartItem({
    required this.id,
    required this.tripId,
    required this.productId,
    required this.addedAt,
    this.quantity = 1,
    this.price,
    this.take = true,
  }) : assert(quantity > 0);

  final String id;
  final String tripId;
  final String productId;
  final int quantity;

  /// Preço de uma unidade; `null` enquanto ninguém leu nem digitou.
  final Money? price;
  final bool take;

  /// Quando foi bipado pela última vez: os mais recentes aparecem primeiro.
  final DateTime addedAt;

  /// O que o item soma ao total: o preço vezes a quantidade, se vai levar.
  Money? get subtotal {
    final price = this.price;
    return take && price != null ? Money.cents(price.cents * quantity) : null;
  }

  @override
  bool operator ==(Object other) =>
      other is CartItem &&
      other.id == id &&
      other.tripId == tripId &&
      other.productId == productId &&
      other.quantity == quantity &&
      other.price == price &&
      other.take == take &&
      other.addedAt == addedAt;

  @override
  int get hashCode => Object.hash(id, tripId, productId, quantity, price, take, addedAt);
}

/// Item do carrinho com o produto.
@immutable
final class CartEntry {
  const CartEntry({required this.item, required this.product});

  final CartItem item;
  final Product product;

  @override
  bool operator ==(Object other) => other is CartEntry && other.item == item && other.product == product;

  @override
  int get hashCode => Object.hash(item, product);
}

/// Acesso ao carrinho de cada compra.
abstract interface class CartRepository {
  /// Itens da compra, do bipado mais recente para o mais antigo.
  Stream<List<CartEntry>> watchTrip(String tripId);

  /// Põe o produto no carrinho. Se ele já está, soma uma unidade e o traz
  /// para o topo; [price], quando informado, substitui o preço.
  Future<void> addProduct(String tripId, String productId, {Money? price});

  Future<void> setPrice(String itemId, Money price);

  Future<void> setTake(String itemId, {required bool take});
}
