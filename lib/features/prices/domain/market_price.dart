import 'package:bipa/features/prices/domain/price_observation.dart';
import 'package:bipa/features/products/domain/product_package.dart';
import 'package:meta/meta.dart';

/// O preço mais recente de um produto, numa embalagem, num mercado: uma
/// linha de "Preços recentes" na tela do mercado.
@immutable
final class MarketPrice {
  const MarketPrice({required this.observation, required this.productName, this.package});

  final PriceObservation observation;
  final String productName;

  /// Nula para produto sem embalagem, como os a granel.
  final ProductPackage? package;

  @override
  bool operator ==(Object other) =>
      other is MarketPrice &&
      other.observation == observation &&
      other.productName == productName &&
      other.package == package;

  @override
  int get hashCode => Object.hash(observation, productName, package);

  @override
  String toString() => 'MarketPrice($productName, ${package?.label}, ${observation.price.format()})';
}
