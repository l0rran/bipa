import 'dart:math' as math;

import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/stock/domain/stock_location.dart';
import 'package:meta/meta.dart';

/// Quantidade de um produto disponível em casa.
@immutable
final class StockItem {
  const StockItem({
    required this.productId,
    required this.quantity,
    required this.location,
    required this.updatedAt,
    this.targetQuantity,
  });

  final String productId;
  final double quantity;

  /// Quanto a pessoa quer ter sempre em casa. Abaixo disso, o item está
  /// acabando; `null` desliga o alerta.
  final double? targetQuantity;
  final StockLocation location;
  final DateTime updatedAt;

  bool get isOut => quantity <= 0;

  bool get isLow => level != StockLevel.ok;

  /// Em dia, acabando (abaixo do "ter sempre") ou acabou.
  StockLevel get level {
    if (isOut) return StockLevel.out;
    final target = targetQuantity;
    return target != null && quantity < target ? StockLevel.low : StockLevel.ok;
  }

  /// Quanto do "ter sempre" está em casa, de 0 a 1. Sem meta, conta como cheio.
  double get fillFraction {
    final target = targetQuantity;
    if (target == null || target <= 0) return isOut ? 0.0 : 1.0;
    return (quantity / target).clamp(0.0, 1.0);
  }

  /// Quantas embalagens faltam para o "ter sempre", pelo menos 1: com 1 em
  /// casa e "ter sempre 4", faltam 3. Sem "ter sempre", 1. É a quantidade
  /// sugerida ao pôr o produto na lista.
  int get toBuy {
    final target = targetQuantity;
    if (target == null) return 1;
    return math.max(1, (target - quantity).ceil());
  }

  /// Aplica uma variação sem permitir estoque negativo.
  static double nextQuantity(double current, double delta) => math.max(0.0, current + delta);

  @override
  bool operator ==(Object other) =>
      other is StockItem &&
      other.productId == productId &&
      other.quantity == quantity &&
      other.targetQuantity == targetQuantity &&
      other.location == location &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(productId, quantity, targetQuantity, location, updatedAt);
}

/// Estado do estoque de um item, que define a cor do medidor.
enum StockLevel {
  /// No "ter sempre" ou acima.
  ok,

  /// Abaixo do "ter sempre".
  low,

  /// Zerado.
  out,
}

/// Item de estoque com os dados do produto, para exibição.
@immutable
final class StockEntry {
  const StockEntry({required this.item, required this.product});

  final StockItem item;
  final Product product;

  @override
  bool operator ==(Object other) => other is StockEntry && other.item == item && other.product == product;

  @override
  int get hashCode => Object.hash(item, product);
}
