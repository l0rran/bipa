import 'package:bipa/core/money/money.dart';
import 'package:bipa/core/time/clock.dart';
import 'package:bipa/core/transactions/unit_of_work.dart';
import 'package:bipa/features/prices/domain/price_source.dart';
import 'package:bipa/features/prices/domain/price_tag.dart';
import 'package:bipa/features/prices/domain/register_price_observation.dart';
import 'package:bipa/features/shopping_list/domain/cart_item.dart';
import 'package:bipa/features/shopping_list/domain/shopping_trip.dart';
import 'package:bipa/features/shopping_list/domain/trip_price.dart';

/// Caso de uso: guarda o preço lido ou digitado para um item da compra (ADR
/// 0020).
///
/// Com mercado, o preço vira observação na hora e corrige a que o item já
/// tinha nesta compra no mesmo mercado (ADR 0017). Sem mercado, fica
/// pendente com a compra, e [SetTripMarket] o grava quando ela ganhar um.
final class RecordTripPrice {
  const RecordTripPrice({
    required ShoppingTripRepository trips,
    required TripPriceRepository prices,
    required RegisterPriceObservation register,
    required UnitOfWork work,
    required Clock clock,
  }) : _trips = trips,
       _prices = prices,
       _register = register,
       _work = work,
       _clock = clock;

  final ShoppingTripRepository _trips;
  final TripPriceRepository _prices;
  final RegisterPriceObservation _register;
  final UnitOfWork _work;
  final Clock _clock;

  /// Devolve `false` quando nada foi gravado: a compra já não está em
  /// andamento, ou é a mesma etiqueta lida de novo, com o mesmo preço.
  Future<bool> call({
    required String tripId,
    required String productId,
    required Money price,
    required PriceSource source,
    String? packageId,
    List<PriceOffer> otherOffers = const [],
  }) async {
    final trip = await _trips.findActive();
    if (trip == null || trip.id != tripId) return false;
    final marketId = trip.marketId;
    final previous = await _prices.find(tripId, CartItem.keyOf(productId, packageId));
    // A etiqueta volta à moldura a cada vez que o celular se move: repetir o
    // preço no mesmo mercado encheria o histórico do mesmo valor.
    final sameTag =
        source == PriceSource.priceTag &&
        previous != null &&
        previous.source == PriceSource.priceTag &&
        previous.price == price &&
        previous.marketId == marketId;
    if (sameTag) return false;

    final readAt = _clock();
    return _work.run(() async {
      final recorded = marketId == null
          ? null
          : await _register(
              RegisterPriceInput(
                marketId: marketId,
                productId: productId,
                packageId: packageId,
                price: price,
                source: source,
                otherOffers: otherOffers,
                // Só corrige no mesmo mercado: o preço do anterior, deixado
                // lá ao trocar de loja, continua valendo.
                supersedes: previous?.marketId == marketId ? previous?.observationId : null,
                observedAt: readAt,
              ),
            );
      await _prices.save(
        TripPrice(
          tripId: tripId,
          productId: productId,
          packageId: packageId,
          price: price,
          source: source,
          readAt: readAt,
          otherOffers: otherOffers,
          observationId: recorded?.id,
          marketId: recorded == null ? null : marketId,
        ),
      );
      return true;
    });
  }
}
