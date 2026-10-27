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
    this.minimumQuantity,
  });

  final String productId;
  final double quantity;

  /// Abaixo (ou no) mínimo, o item aparece como "acabando".
  final double? minimumQuantity;
  final StockLocation location;
  final DateTime updatedAt;

  bool get isOut => quantity <= 0;

  bool get isLow {
    final minimum = minimumQuantity;
    return isOut || (minimum != null && quantity <= minimum);
  }

  /// Aplica uma variação sem permitir estoque negativo.
  static double nextQuantity(double current, double delta) => math.max(0.0, current + delta);

  @override
  bool operator ==(Object other) =>
      other is StockItem &&
      other.productId == productId &&
      other.quantity == quantity &&
      other.minimumQuantity == minimumQuantity &&
      other.location == location &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(productId, quantity, minimumQuantity, location, updatedAt);
}

/// Item de estoque com os dados do produto, para exibição.
@immutable
final class StockEntry {
  const StockEntry({required this.item, required this.product});

  final StockItem item;
  final Product product;

  @override
  bool operator ==(Object other) =>
      other is StockEntry && other.item == item && other.product == product;

  @override
  int get hashCode => Object.hash(item, product);
}
