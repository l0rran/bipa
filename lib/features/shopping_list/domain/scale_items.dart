import 'package:bipa/core/money/money.dart';
import 'package:bipa/features/products/domain/create_product_by_weight.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/products/domain/product_repository.dart';
import 'package:bipa/features/products/domain/scale_label.dart';
import 'package:bipa/features/shopping_list/domain/cart_item.dart';

/// Que produto é cada código da balança em cada mercado (ADR 0018).
abstract interface class ScaleItemRepository {
  Future<String?> productIdFor(String marketId, String itemKey);

  Future<void> remember(String marketId, String itemKey, String productId);

  /// Os códigos lembrados para o produto no mercado.
  Future<List<String>> keysFor(String marketId, String productId);

  /// Os produtos com algum código lembrado no mercado.
  Stream<Set<String>> watchProductIdsIn(String marketId);
}

/// Caso de uso: a etiqueta da balança no modo carrinho (ADR 0018). O código
/// do item é perguntado uma vez por mercado ("Banana prata") e lembrado; o
/// código inteiro nunca vira embalagem, porque muda a cada pesagem.
final class ScaleItems {
  const ScaleItems({
    required ScaleItemRepository scale,
    required ProductRepository products,
    required CartRepository cart,
    required CreateProductByWeight createProduct,
  }) : _scale = scale,
       _products = products,
       _cart = cart,
       _createProduct = createProduct;

  final ScaleItemRepository _scale;
  final ProductRepository _products;
  final CartRepository _cart;
  final CreateProductByWeight _createProduct;

  /// O produto já lembrado para o item neste mercado; sem mercado, nenhum.
  Future<Product?> productFor(String? marketId, ScaleLabel label) async {
    if (marketId == null) return null;
    final productId = await _scale.productIdFor(marketId, label.itemKey);
    return productId == null ? null : _products.findById(productId);
  }

  /// Lembra o produto escolhido para o item ([product], ou um novo chamado
  /// [newName], vendido por kg). Sem mercado, só cria o produto, se for o
  /// caso: o código não diz nada fora daquele mercado.
  Future<Product> remember(String? marketId, ScaleLabel label, {Product? product, String? newName}) async {
    final chosen = product ?? await _createProduct(newName ?? (throw ArgumentError('Sem produto nem nome.')));
    if (marketId != null) await _scale.remember(marketId, label.itemKey, chosen.id);
    return chosen;
  }

  /// Põe a pesagem no carrinho. Duas pesagens do mesmo produto (dois sacos
  /// de tomate) somam o valor numa linha só, que conta como uma embalagem.
  ///
  /// Só soma numa linha que já é de pesagens: uma embalagem, para levar, com
  /// preço firmado. Uma linha com outro preço (o por kg da etiqueta, ou um
  /// estimado) passa a ser a da pesagem.
  Future<void> addToCart(String tripId, Product product, ScaleLabel label) async {
    final cart = await _cart.watchTrip(tripId).first;
    final existing = cart
        .where((entry) => entry.item.productId == product.id && entry.item.packageId == null)
        .firstOrNull
        ?.item;
    if (existing == null) {
      await _cart.addProduct(tripId, product.id, price: label.total);
      return;
    }
    final weighed = existing.quantity == 1 && existing.take && !existing.priceEstimated;
    final previous = weighed ? existing.price ?? Money.zero : Money.zero;
    await _cart.setPrice(existing.id, previous + label.total);
    if (existing.quantity != 1) await _cart.setQuantity(existing.id, 1);
    if (!existing.take) await _cart.setTake(existing.id, take: true);
  }

  /// Troca o produto de uma pesagem lembrado errado ("Banana nanica" no lugar
  /// de "Banana prata", D6): os códigos do produto antigo neste mercado
  /// passam a ser do novo, e a linha do carrinho vai para ele. Se o novo já
  /// tem uma linha de pesagens, o valor soma nela, como numa pesagem a mais.
  Future<void> swapProduct(String tripId, String? marketId, CartItem item, Product to) async {
    if (to.id == item.productId) return;
    if (marketId != null) {
      for (final key in await _scale.keysFor(marketId, item.productId)) {
        await _scale.remember(marketId, key, to.id);
      }
    }
    final cart = await _cart.watchTrip(tripId).first;
    final existing = cart
        .where((entry) => entry.item.productId == to.id && entry.item.packageId == null)
        .firstOrNull
        ?.item;
    final price = item.price;
    if (existing == null) {
      await _cart.addProduct(tripId, to.id, price: price);
      if (!item.take) {
        final added = (await _cart.watchTrip(tripId).first)
            .where((entry) => entry.item.productId == to.id && entry.item.packageId == null)
            .first
            .item;
        await _cart.setTake(added.id, take: false);
      }
    } else if (price != null) {
      await _cart.setPrice(existing.id, (existing.price ?? Money.zero) + price);
    }
    await _cart.remove(item.id);
  }
}
