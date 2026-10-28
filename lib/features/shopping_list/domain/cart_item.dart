import 'package:bipa/core/money/money.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/products/domain/product_package.dart';
import 'package:meta/meta.dart';

/// Uma embalagem no carrinho da compra em andamento (o modo carrinho).
///
/// Bipar a mesma embalagem de novo soma uma unidade; outra embalagem do mesmo
/// produto (o arroz de 10 kg depois do de 5 kg) é outro item (ADR 0013). Com [take] desligado, o
/// preço fica registrado para comparação, mas o item não entra no total nem
/// no estoque.
@immutable
final class CartItem {
  const CartItem({
    required this.id,
    required this.tripId,
    required this.productId,
    required this.addedAt,
    this.packageId,
    this.quantity = 1,
    this.price,
    this.priceEstimated = false,
    this.take = true,
  }) : assert(quantity > 0);

  final String id;
  final String tripId;
  final String productId;

  /// A embalagem bipada; nula quando o preço veio de um produto sem
  /// embalagem.
  final String? packageId;
  final int quantity;

  /// Preço de uma unidade; `null` enquanto ninguém leu nem digitou.
  final Money? price;

  /// O [price] é o último do mercado, do histórico: uma estimativa até a
  /// etiqueta ser lida ou o preço digitado nesta compra.
  final bool priceEstimated;
  final bool take;

  /// Quando foi bipado pela última vez: os mais recentes aparecem primeiro.
  final DateTime addedAt;

  /// O que identifica o item numa compra: a embalagem ou, sem ela, o
  /// produto. Igual para o mesmo item entre telas, ao contrário do [id], que
  /// só existe depois de o item entrar no carrinho.
  String get key => keyOf(productId, packageId);

  static String keyOf(String productId, String? packageId) => '$productId:${packageId ?? ''}';

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
      other.packageId == packageId &&
      other.quantity == quantity &&
      other.price == price &&
      other.priceEstimated == priceEstimated &&
      other.take == take &&
      other.addedAt == addedAt;

  @override
  int get hashCode => Object.hash(id, tripId, productId, packageId, quantity, price, priceEstimated, take, addedAt);
}

/// Item do carrinho com o produto e a embalagem.
@immutable
final class CartEntry {
  const CartEntry({required this.item, required this.product, this.package});

  final CartItem item;
  final Product product;
  final ProductPackage? package;

  /// "Arroz branco Tio João 5 kg": o produto, a marca e o tamanho.
  String get name => nameOf(product, package);

  static String nameOf(Product product, ProductPackage? package) =>
      [product.name, ?package?.brand, ?package?.sizeLabel].join(' ');

  @override
  bool operator ==(Object other) =>
      other is CartEntry && other.item == item && other.product == product && other.package == package;

  @override
  int get hashCode => Object.hash(item, product, package);
}

/// Acesso ao carrinho de cada compra.
abstract interface class CartRepository {
  /// Itens da compra, do bipado mais recente para o mais antigo.
  Stream<List<CartEntry>> watchTrip(String tripId);

  /// Põe a embalagem (ou o produto, sem [packageId]) no carrinho. Se ela já
  /// está, soma uma unidade e a traz para o topo; [price], quando informado,
  /// substitui o preço. Um preço [estimated] (do histórico) nunca substitui
  /// um lido ou digitado nesta compra.
  Future<void> addProduct(String tripId, String productId, {String? packageId, Money? price, bool estimated = false});

  /// Preço lido ou digitado: deixa de ser estimado.
  Future<void> setPrice(String itemId, Money price);

  /// Quantas unidades vão (pelo menos uma).
  Future<void> setQuantity(String itemId, int quantity);

  /// Guarda o preço lido na etiqueta. Se a embalagem (ou o produto, sem
  /// [packageId]) ainda não está no carrinho, entra com uma unidade; se já
  /// está, só o preço muda.
  Future<void> setPriceForProduct(String tripId, String productId, Money price, {String? packageId});

  Future<void> setTake(String itemId, {required bool take});

  /// O mesmo, pelo produto: usado quando a pessoa marca ou desmarca o item
  /// na lista durante a compra. Não faz nada se ele não está no carrinho.
  Future<void> setTakeForProduct(String tripId, String productId, {required bool take});
}
