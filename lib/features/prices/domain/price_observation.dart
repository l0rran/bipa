import 'package:bipa/core/money/money.dart';
import 'package:bipa/features/prices/domain/price_condition.dart';
import 'package:bipa/features/prices/domain/price_source.dart';
import 'package:meta/meta.dart';

/// Registro de que um produto custava [price] em um mercado em [observedAt].
///
/// Observações são imutáveis e apenas inseridas (nunca editadas), o que torna
/// a sincronização com o servidor livre de conflitos.
@immutable
final class PriceObservation {
  const PriceObservation({
    required this.id,
    required this.productId,
    required this.marketId,
    required this.price,
    required this.source,
    required this.observedAt,
    required this.createdAt,
    this.regularPrice,
    this.condition = const AnyCustomer(),
  });

  final String id;
  final String productId;
  final String marketId;

  /// Preço efetivamente cobrado.
  final Money price;

  /// Preço sem desconto, quando o produto estava em promoção.
  final Money? regularPrice;

  /// Para quem o preço vale: qualquer cliente, cartão da loja ou atacado.
  final PriceCondition condition;
  final PriceSource source;
  final DateTime observedAt;
  final DateTime createdAt;

  bool get isPromotion {
    final regular = regularPrice;
    return regular != null && regular > price;
  }

  @override
  bool operator ==(Object other) =>
      other is PriceObservation &&
      other.id == id &&
      other.productId == productId &&
      other.marketId == marketId &&
      other.price == price &&
      other.regularPrice == regularPrice &&
      other.condition == condition &&
      other.source == source &&
      other.observedAt == observedAt &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(
    id,
    productId,
    marketId,
    price,
    regularPrice,
    condition,
    source,
    observedAt,
    createdAt,
  );

  @override
  String toString() => 'PriceObservation($productId @ $marketId: ${price.format()})';
}

/// Observação de preço com o nome do mercado, para exibição.
@immutable
final class PriceHistoryEntry {
  const PriceHistoryEntry({required this.observation, required this.marketName});

  final PriceObservation observation;
  final String marketName;

  @override
  bool operator ==(Object other) =>
      other is PriceHistoryEntry &&
      other.observation == observation &&
      other.marketName == marketName;

  @override
  int get hashCode => Object.hash(observation, marketName);
}
