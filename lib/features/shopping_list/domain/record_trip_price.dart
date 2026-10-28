import 'package:bipa/core/money/money.dart';
import 'package:bipa/core/time/clock.dart';
import 'package:bipa/core/transactions/unit_of_work.dart';
import 'package:bipa/features/prices/domain/price_source.dart';
import 'package:bipa/features/prices/domain/price_tag.dart';
import 'package:bipa/features/prices/domain/register_price_observation.dart';
import 'package:bipa/features/shopping_list/domain/shopping_trip.dart';
import 'package:bipa/features/shopping_list/domain/trip_price.dart';

/// Caso de uso: guarda o preço lido ou digitado para um item da compra (ADR
/// 0020).
///
/// Com mercado, o preço vira observação na hora e corrige a que o item já
/// tinha nesta compra no mesmo mercado (ADR 0017). Sem mercado, fica
/// pendente com a compra, e [SetTripMarket] o grava quando ela ganhar um.
///
/// O valor digitado na linha da pesagem ou do granel ([isWeighingLine]) é o
/// total pago pelo peso, não o preço do produto (ADR 0018): não vira
/// observação nem fica pendente, e vale só para o carrinho.
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
  /// andamento, é a mesma etiqueta lida de novo com o mesmo preço, é uma
  /// etiqueta para um item cujo preço foi digitado neste mercado, ou é o
  /// valor digitado de uma pesagem.
  Future<bool> call({
    required String tripId,
    required String productId,
    required Money price,
    required PriceSource source,
    String? packageId,
    List<PriceOffer> otherOffers = const [],
    bool perKilo = false,
  }) async {
    final trip = await _trips.findActive();
    if (trip == null || trip.id != tripId) return false;
    final marketId = trip.marketId;
    final previous = await _prices.find(tripId, TripPrice.keyOf(productId, packageId, perKilo: perKilo));
    // O tomate a R$ 8,99/kg pago R$ 12,40 no caixa: os R$ 12,40 são da
    // pesagem, e no histórico virariam o preço do quilo. Sem guardar, o
    // SetTripMarket também não o grava depois.
    if (source == PriceSource.manual && !perKilo && isWeighingLine(packageId: packageId, shelfPrice: previous)) {
      return false;
    }
    if (previous != null && previous.marketId == marketId && source == PriceSource.priceTag) {
      // A etiqueta volta à moldura a cada vez que o celular se move: repetir
      // o preço encheria o histórico do mesmo valor.
      if (previous.source == PriceSource.priceTag && previous.price == price) return false;
      // O preço digitado é a correção da leitura (ADR 0017): a mesma etiqueta
      // lida errado de novo não pode desfazê-la.
      if (previous.source == PriceSource.manual) return false;
    }

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
          perKilo: perKilo,
        ),
      );
      return true;
    });
  }
}
