import 'package:bipa/core/transactions/unit_of_work.dart';
import 'package:bipa/features/prices/domain/register_price_observation.dart';
import 'package:bipa/features/shopping_list/domain/shopping_trip.dart';
import 'package:bipa/features/shopping_list/domain/trip_price.dart';

/// Caso de uso: muda o mercado da compra e leva os preços dela junto (ADR
/// 0020).
///
/// Os preços que esperavam o mercado são gravados nele, com a hora em que
/// foram lidos. Os que já estavam gravados em outro mercado só vão junto
/// com [movePrices]: cada um ganha uma correção no mercado novo (ADR 0017),
/// sem apagar nada. Quem foi a duas lojas na mesma compra os deixa onde
/// estão.
final class SetTripMarket {
  const SetTripMarket({
    required ShoppingTripRepository trips,
    required TripPriceRepository prices,
    required RegisterPriceObservation register,
    required UnitOfWork work,
  }) : _trips = trips,
       _prices = prices,
       _register = register,
       _work = work;

  final ShoppingTripRepository _trips;
  final TripPriceRepository _prices;
  final RegisterPriceObservation _register;
  final UnitOfWork _work;

  /// Quantos preços da compra já estão gravados no mercado dela: trocar o
  /// mercado pergunta se eles vão junto.
  Future<int> recordedPrices(String tripId) async =>
      (await _prices.ofTrip(tripId)).where((price) => !price.isPending).length;

  /// Quantos preços da compra esperam um mercado.
  Future<int> pendingPrices(String tripId) async =>
      (await _prices.ofTrip(tripId)).where((price) => price.isPending).length;

  Future<void> call(String tripId, String marketId, {bool movePrices = false}) async {
    final trip = await _trips.findActive();
    if (trip == null || trip.id != tripId || trip.marketId == marketId) return;
    final prices = await _prices.ofTrip(tripId);
    await _work.run(() async {
      await _trips.setMarket(tripId, marketId);
      for (final price in prices) {
        if (!price.isPending && !movePrices) continue;
        final recorded = await _register(
          RegisterPriceInput(
            marketId: marketId,
            productId: price.productId,
            packageId: price.packageId,
            price: price.price,
            source: price.source,
            otherOffers: price.otherOffers,
            // Mover é corrigir: a do mercado anterior deixa de valer.
            supersedes: price.observationId,
            observedAt: price.readAt,
          ),
        );
        await _prices.save(price.recordedAs(recorded.id, market: marketId));
      }
    });
  }
}
