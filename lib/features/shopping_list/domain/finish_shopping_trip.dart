import 'package:bipa/features/shopping_list/domain/cart_item.dart';
import 'package:bipa/features/shopping_list/domain/shopping_list_item.dart';
import 'package:bipa/features/shopping_list/domain/shopping_list_repository.dart';
import 'package:bipa/features/shopping_list/domain/shopping_trip.dart';
import 'package:bipa/features/stock/domain/stock_movement_reason.dart';
import 'package:bipa/features/stock/domain/stock_repository.dart';
import 'package:meta/meta.dart';

/// O que o "Terminei" fez, para poder desfazer.
@immutable
final class FinishedShoppingTrip {
  const FinishedShoppingTrip({
    required this.tripId,
    required this.bought,
    required this.stocked,
    this.stockedPackages = const {},
  });

  final String tripId;

  /// Itens marcados na lista, que saíram dela.
  final List<ShoppingListItem> bought;

  /// Quantas unidades de cada produto entraram no estoque.
  final Map<String, int> stocked;

  /// As mesmas unidades por (produto, embalagem), para o desfazer tirar
  /// exatamente as embalagens que entraram (ADR 0013).
  final Map<(String, String?), int> stockedPackages;
}

/// Caso de uso: termina a compra. Entra no estoque o que está no carrinho
/// para levar (na quantidade bipada) e o que foi marcado à mão na lista (uma
/// embalagem). O marcado sai da lista; o que faltou continua nela.
final class FinishShoppingTrip {
  FinishShoppingTrip({
    required ShoppingTripRepository trips,
    required ShoppingListRepository list,
    required CartRepository cart,
    required StockRepository stock,
  }) : _trips = trips,
       _list = list,
       _cart = cart,
       _stock = stock;

  final ShoppingTripRepository _trips;
  final ShoppingListRepository _list;
  final CartRepository _cart;
  final StockRepository _stock;

  /// Devolve `null` se a compra já não está em andamento (por exemplo, num
  /// segundo toque em "Terminei"), sem mexer no estoque de novo.
  Future<FinishedShoppingTrip?> call(String tripId) async {
    final active = await _trips.watchActive().first;
    if (active?.id != tripId) return null;
    // Fecha a compra primeiro: um segundo "Terminei" já não passa da guarda.
    await _trips.finish(tripId);

    final cart = await _cart.watchTrip(tripId).first;
    final entries = await _list.watchAll().first;
    final bought = [
      for (final entry in entries)
        if (entry.item.isChecked) entry.item,
    ];

    // Cada embalagem do carrinho entra no estoque do seu produto; embalagens
    // diferentes do mesmo produto somam nele.
    final byPackage = <(String, String?), int>{};
    for (final entry in cart) {
      final quantity = entry.item.quantity;
      final key = (entry.item.productId, entry.item.packageId);
      if (entry.item.take) byPackage.update(key, (q) => q + quantity, ifAbsent: () => quantity);
    }
    // O que foi marcado à mão, sem passar pelo carrinho, entra com uma unidade.
    // O que está no carrinho sem "levar" não entra.
    final inCart = {for (final entry in cart) entry.item.productId};
    for (final item in bought) {
      final productId = item.productId;
      if (productId != null && !inCart.contains(productId)) byPackage[(productId, null)] = 1;
    }

    final stocked = <String, int>{};
    for (final MapEntry(key: (productId, packageId), value: quantity) in byPackage.entries) {
      await _stock.adjust(
        productId: productId,
        packageId: packageId,
        delta: quantity.toDouble(),
        reason: StockMovementReason.purchase,
      );
      stocked.update(productId, (q) => q + quantity, ifAbsent: () => quantity);
    }
    await _list.removeChecked();
    return FinishedShoppingTrip(tripId: tripId, bought: bought, stocked: stocked, stockedPackages: byPackage);
  }

  /// Desfaz o [call]: tira do estoque o que entrou, devolve os itens à lista
  /// e reabre a compra, se nenhuma outra tiver começado nesse meio-tempo.
  Future<void> undo(FinishedShoppingTrip finished) async {
    for (final MapEntry(key: (productId, packageId), value: quantity) in finished.stockedPackages.entries) {
      await _stock.adjust(
        productId: productId,
        packageId: packageId,
        delta: -quantity.toDouble(),
        reason: StockMovementReason.adjustment,
      );
    }
    for (final item in finished.bought) {
      await _list.restore(item);
    }
    await _trips.reopen(finished.tripId);
  }
}
