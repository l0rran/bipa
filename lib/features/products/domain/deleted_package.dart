import 'package:bipa/features/prices/domain/price_observation.dart';
import 'package:bipa/features/products/domain/product_package.dart';
import 'package:meta/meta.dart';

/// O que "Apagar embalagem" tirou (ADR 0022), para o "Desfazer" gravar de
/// volta igual: a embalagem, as observações de preço dela e quais lotes e
/// linhas de carrinho ficaram sem embalagem.
@immutable
final class DeletedPackage {
  const DeletedPackage({
    required this.package,
    this.prices = const [],
    this.lotIds = const {},
    this.cartItemIds = const {},
  });

  final ProductPackage package;

  /// As observações apagadas, como eram.
  final List<PriceObservation> prices;

  /// Os lotes de estoque que continuam em casa, agora sem embalagem.
  final Set<String> lotIds;

  /// As linhas do carrinho de compras terminadas, agora sem embalagem.
  final Set<String> cartItemIds;
}
