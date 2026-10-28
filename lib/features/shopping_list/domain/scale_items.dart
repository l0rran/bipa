import 'package:bipa/core/id/id_generator.dart';
import 'package:bipa/core/money/money.dart';
import 'package:bipa/core/time/clock.dart';
import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/products/domain/product_repository.dart';
import 'package:bipa/features/products/domain/scale_label.dart';
import 'package:bipa/features/shopping_list/domain/cart_item.dart';

/// Que produto é cada código da balança em cada mercado (ADR 0018).
abstract interface class ScaleItemRepository {
  Future<String?> productIdFor(String marketId, String itemKey);

  Future<void> remember(String marketId, String itemKey, String productId);
}

/// Caso de uso: a etiqueta da balança no modo carrinho (ADR 0018). O código
/// do item é perguntado uma vez por mercado ("Banana prata") e lembrado; o
/// código inteiro nunca vira embalagem, porque muda a cada pesagem.
final class ScaleItems {
  const ScaleItems({
    required ScaleItemRepository scale,
    required ProductRepository products,
    required CartRepository cart,
    required IdGenerator ids,
    required Clock clock,
  }) : _scale = scale,
       _products = products,
       _cart = cart,
       _ids = ids,
       _clock = clock;

  final ScaleItemRepository _scale;
  final ProductRepository _products;
  final CartRepository _cart;
  final IdGenerator _ids;
  final Clock _clock;

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
    final chosen = product ?? await _create(newName ?? (throw ArgumentError('Sem produto nem nome.')));
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

  Future<Product> _create(String name) async {
    final now = _clock();
    final product = Product(
      id: _ids.newId(),
      name: name.trim(),
      unit: MeasureUnit.kilogram,
      createdAt: now,
      updatedAt: now,
    );
    await _products.save(product);
    return product;
  }
}
