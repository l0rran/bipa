import 'package:bipa/core/money/money.dart';
import 'package:bipa/features/prices/domain/price_source.dart';
import 'package:bipa/features/prices/domain/price_tag.dart';
import 'package:bipa/features/shopping_list/domain/cart_item.dart';
import 'package:meta/meta.dart';

/// O último preço lido ou digitado para um item da compra (ADR 0020).
///
/// Fica guardado com a compra, e não na tela do carrinho: sem mercado, ele
/// espera aqui ([isPending]) até a compra ganhar um; com mercado, aponta a
/// observação gravada ([observationId]), que um preço novo do mesmo item
/// corrige (ADR 0017).
@immutable
final class TripPrice {
  const TripPrice({
    required this.tripId,
    required this.productId,
    required this.price,
    required this.source,
    required this.readAt,
    this.packageId,
    this.otherOffers = const [],
    this.observationId,
    this.marketId,
    this.perKilo = false,
  });

  final String tripId;
  final String productId;
  final String? packageId;
  final Money price;
  final PriceSource source;

  /// Os outros preços da mesma etiqueta (cartão, atacado), para o histórico
  /// (ADR 0011).
  final List<PriceOffer> otherOffers;

  /// Quando o preço foi lido ou digitado: é a hora da observação, mesmo que
  /// ela seja gravada depois.
  final DateTime readAt;

  /// A observação gravada para este preço; `null` enquanto a compra não tem
  /// mercado.
  final String? observationId;

  /// O mercado da [observationId]. Um preço novo do item só corrige a
  /// observação se for do mesmo mercado: quem foi a duas lojas na mesma
  /// compra tem um preço certo em cada uma.
  final String? marketId;

  /// O preço é por quilo, do granel (ADR 0018): é outro preço do item, que
  /// o total da pesagem não corrige, nem ele corrige o total.
  final bool perKilo;

  /// O item da compra, como no carrinho: a embalagem ou, sem ela, o produto;
  /// o preço por quilo tem a chave dele.
  String get itemKey => keyOf(productId, packageId, perKilo: perKilo);

  static String keyOf(String productId, String? packageId, {bool perKilo = false}) {
    final item = CartItem.keyOf(productId, packageId);
    return perKilo ? '$item:kg' : item;
  }

  /// Espera um mercado: ainda sem observação, ou o mercado dela foi apagado
  /// no meio da compra (e a observação foi junto).
  bool get isPending => observationId == null || marketId == null;

  /// O mesmo preço, já gravado como [observation] no [market].
  TripPrice recordedAs(String observation, {required String market}) => TripPrice(
    tripId: tripId,
    productId: productId,
    packageId: packageId,
    price: price,
    source: source,
    readAt: readAt,
    otherOffers: otherOffers,
    observationId: observation,
    marketId: market,
    perKilo: perKilo,
  );

  @override
  bool operator ==(Object other) =>
      other is TripPrice &&
      other.tripId == tripId &&
      other.productId == productId &&
      other.packageId == packageId &&
      other.price == price &&
      other.source == source &&
      other.readAt == readAt &&
      other.observationId == observationId &&
      other.marketId == marketId &&
      other.perKilo == perKilo &&
      _sameOffers(other.otherOffers, otherOffers);

  @override
  int get hashCode => Object.hash(
    tripId,
    productId,
    packageId,
    price,
    source,
    readAt,
    observationId,
    marketId,
    perKilo,
    Object.hashAll(otherOffers),
  );

  static bool _sameOffers(List<PriceOffer> a, List<PriceOffer> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Os preços de cada compra.
abstract interface class TripPriceRepository {
  /// Os preços da compra, do lido primeiro ao último.
  Future<List<TripPrice>> ofTrip(String tripId);

  /// O preço de um item da compra ([TripPrice.itemKey]), se há.
  Future<TripPrice?> find(String tripId, String itemKey);

  /// Guarda o preço, no lugar do que o item tinha.
  Future<void> save(TripPrice price);
}
