import 'package:bipa/core/transactions/unit_of_work.dart';
import 'package:bipa/features/shopping_list/domain/shopping_list_repository.dart';
import 'package:bipa/features/shopping_list/domain/shopping_trip.dart';

/// Caso de uso: desiste da compra. O carrinho é descartado, nada vai para o
/// estoque, e o que foi marcado na lista durante a compra volta a faltar:
/// senão, o próximo "Terminei" levaria para casa o que não foi comprado.
final class CancelShoppingTrip {
  const CancelShoppingTrip({
    required ShoppingTripRepository trips,
    required ShoppingListRepository list,
    required UnitOfWork work,
  }) : _trips = trips,
       _list = list,
       _work = work;

  final ShoppingTripRepository _trips;
  final ShoppingListRepository _list;
  final UnitOfWork _work;

  Future<void> call(String tripId) async {
    final trip = await _trips.findActive();
    if (trip == null || trip.id != tripId) return;
    // A lista é lida antes da transação, como em FinishShoppingTrip.
    final checked = [
      for (final entry in await _list.watchAll().first)
        if (entry.item.isCheckedSince(trip.startedAt)) entry.item.id,
    ];
    await _work.run(() async {
      for (final itemId in checked) {
        await _list.setChecked(itemId, checked: false);
      }
      await _trips.cancel(tripId);
    });
  }
}
