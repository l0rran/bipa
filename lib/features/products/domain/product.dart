import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:meta/meta.dart';

/// Produto que pode ser comprado, identificado opcionalmente por um código de
/// barras (GTIN/EAN).
@immutable
final class Product {
  const Product({
    required this.id,
    required this.name,
    required this.unit,
    required this.createdAt,
    required this.updatedAt,
    this.barcode,
    this.brand,
    this.packageSize,
  });

  final String id;
  final String name;
  final String? barcode;
  final String? brand;

  /// Unidade em que [packageSize] é expresso (ex.: 395 g, 1 L, 12 un).
  final MeasureUnit unit;
  final double? packageSize;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Descrição curta da embalagem, como `395 g` ou `1,5 L`.
  String? get packageLabel {
    final size = packageSize;
    if (size == null) return null;
    final formatted = size == size.truncateToDouble()
        ? size.toStringAsFixed(0)
        : size.toString().replaceAll('.', ',');
    return '$formatted ${unit.symbol}';
  }

  /// Linha de apoio para listas: marca e embalagem, quando conhecidas.
  String? get subtitle {
    final parts = [?brand, ?packageLabel];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  @override
  bool operator ==(Object other) =>
      other is Product &&
      other.id == id &&
      other.name == name &&
      other.barcode == barcode &&
      other.brand == brand &&
      other.unit == unit &&
      other.packageSize == packageSize &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    barcode,
    brand,
    unit,
    packageSize,
    createdAt,
    updatedAt,
  );

  @override
  String toString() => 'Product($id, $name)';
}
