import 'package:bipa/features/shopping_list/domain/shopping_list_item.dart';
import 'package:bipa/features/shopping_list/domain/shopping_list_repository.dart';
import 'package:bipa/features/shopping_list/domain/shopping_trip.dart';
import 'package:bipa/features/stock/domain/stock_movement_reason.dart';
import 'package:bipa/features/stock/domain/stock_repository.dart';
import 'package:meta/meta.dart';

/// O que o "Terminei" fez, para poder desfazer.
@immutable
final class FinishedShoppingTrip {
  const FinishedShoppingTrip({required this.tripId, required this.bought});

  final String tripId;

  /// Itens marcados como comprados, que saíram da lista.
  final List<ShoppingListItem> bought;

  /// Produtos que entraram no estoque, um de cada.
  Iterable<String> get stockedProductIds => bought.map((item) => item.productId).nonNulls;
}

/// Caso de uso: termina a compra. O que foi comprado entra no estoque (uma
/// embalagem de cada) e sai da lista; o que faltou continua nela.
final class FinishShoppingTrip {
  FinishShoppingTrip({
    required ShoppingTripRepository trips,
    required ShoppingListRepository list,
    required StockRepository stock,
  }) : _trips = trips,
       _list = list,
       _stock = stock;

  final ShoppingTripRepository _trips;
  final ShoppingListRepository _list;
  final StockRepository _stock;

  /// Devolve `null` se a compra já não está em andamento (por exemplo, num
  /// segundo toque em "Terminei"), sem mexer no estoque de novo.
  Future<FinishedShoppingTrip?> call(String tripId) async {
    final active = await _trips.watchActive().first;
    if (active?.id != tripId) return null;
    // Fecha a compra primeiro: um segundo "Terminei" já não passa da guarda.
    await _trips.finish(tripId);

    final entries = await _list.watchAll().first;
    final bought = [
      for (final entry in entries)
        if (entry.item.isChecked) entry.item,
    ];
    final finished = FinishedShoppingTrip(tripId: tripId, bought: bought);

    for (final productId in finished.stockedProductIds) {
      await _stock.adjust(productId: productId, delta: 1, reason: StockMovementReason.purchase);
    }
    await _list.removeChecked();
    return finished;
  }

  /// Desfaz o [call]: tira do estoque o que entrou, devolve os itens à lista
  /// e reabre a compra, se nenhuma outra tiver começado nesse meio-tempo.
  Future<void> undo(FinishedShoppingTrip finished) async {
    for (final productId in finished.stockedProductIds) {
      await _stock.adjust(productId: productId, delta: -1, reason: StockMovementReason.adjustment);
    }
    for (final item in finished.bought) {
      await _list.restore(item);
    }
    await _trips.reopen(finished.tripId);
  }
}
