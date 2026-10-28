import 'package:bipa/features/prices/domain/list_cost.dart';
import 'package:bipa/features/prices/domain/price_repository.dart';
import 'package:bipa/features/products/domain/product_repository.dart';
import 'package:bipa/features/shopping_list/domain/cart_item.dart';
import 'package:bipa/features/shopping_list/domain/shopping_list_repository.dart';
import 'package:bipa/features/shopping_list/domain/shopping_trip.dart';
import 'package:bipa/features/shopping_list/domain/trip_review.dart';

/// Caso de uso: monta a folha "Fim da compra" antes do "Terminei", com o
/// carrinho, a lista e os preços dos produtos da compra em cada mercado.
/// Só lê; quem termina é o FinishShoppingTrip.
final class ReviewShoppingTrip {
  const ReviewShoppingTrip({
    required ShoppingTripRepository trips,
    required ShoppingListRepository list,
    required CartRepository cart,
    required PriceRepository prices,
    required ProductRepository products,
  }) : _trips = trips,
       _list = list,
       _cart = cart,
       _prices = prices,
       _products = products;

  final ShoppingTripRepository _trips;
  final ShoppingListRepository _list;
  final CartRepository _cart;
  final PriceRepository _prices;
  final ProductRepository _products;

  /// `null` se a compra já não está em andamento.
  Future<TripReview?> call(String tripId) async {
    final trip = await _trips.findActive();
    if (trip == null || trip.id != tripId) return null;

    final cart = await _cart.watchTrip(tripId).first;
    final entries = await _list.watchAll().first;
    final productIds = {
      for (final entry in cart) entry.item.productId,
      for (final entry in entries)
        if (entry.item.isChecked) ?entry.item.productId,
    };
    final history = await _prices.watchHistoryOfProducts(productIds).first;
    final packages = await _products.watchPackagesOfProducts(productIds).first;

    return TripReview.of(
      entries: entries,
      cart: cart,
      marketId: trip.marketId,
      prices: referencePricesPerMarket(
        productIds,
        history,
        packages: {for (final package in packages) package.id: package},
        // A cesta é a do carrinho: cada produto na embalagem que foi levada.
        references: {
          for (final entry in cart)
            if (entry.item.take) entry.item.productId: entry.item.packageId,
        },
      ),
    );
  }
}
