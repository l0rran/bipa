import 'package:bipa/core/money/money.dart';
import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:bipa/features/products/domain/package_origin.dart';
import 'package:bipa/features/products/domain/unit_price.dart';
import 'package:meta/meta.dart';

/// Uma embalagem de um produto: o que se compra e se bipa (ADR 0013). O
/// arroz Tio João de 5 kg e o Camil de 10 kg são duas embalagens do mesmo
/// "Arroz branco".
@immutable
final class ProductPackage {
  const ProductPackage({
    required this.id,
    required this.productId,
    required this.unit,
    required this.createdAt,
    required this.updatedAt,
    this.barcode,
    this.brand,
    this.size,
    this.origin = PackageOrigin.person,
  });

  final String id;
  final String productId;

  /// GTIN/EAN; embalagens sem código (a granel, feira) também existem.
  final String? barcode;
  final String? brand;

  /// Quanto a embalagem tem, em [unit]: 5 (kg), 395 (g), 12 (un).
  final double? size;
  final MeasureUnit unit;

  /// De onde vieram os dados: da pessoa ou do catálogo pronto (ADR 0024).
  /// Editar ou mover a embalagem não muda a origem.
  final PackageOrigin origin;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// `5 kg`, `1,5 L`; `null` sem tamanho.
  String? get sizeLabel {
    final size = this.size;
    if (size == null) return null;
    final formatted = size == size.truncateToDouble() ? size.toStringAsFixed(0) : '$size'.replaceAll('.', ',');
    return '$formatted ${unit.symbol}';
  }

  /// `Tio João · 5 kg`; `null` sem marca nem tamanho.
  String? get label {
    final parts = [?brand, ?sizeLabel];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  /// Quanto a embalagem tem na unidade base (kg, L ou un), para somar
  /// embalagens de tamanhos diferentes.
  double? get sizeInBaseUnit {
    final size = this.size;
    return size == null ? null : size * unit.toBaseFactor;
  }

  /// O preço por kg (ou L, ou un) desta embalagem a [price].
  UnitPrice? unitPrice(Money price) => UnitPrice.of(price: price, packageSize: size, unit: unit);

  ProductPackage copyWith({
    String? productId,
    String? barcode,
    String? brand,
    double? size,
    MeasureUnit? unit,
    DateTime? updatedAt,
  }) => ProductPackage(
    id: id,
    productId: productId ?? this.productId,
    barcode: barcode ?? this.barcode,
    brand: brand ?? this.brand,
    size: size ?? this.size,
    unit: unit ?? this.unit,
    origin: origin,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  bool operator ==(Object other) =>
      other is ProductPackage &&
      other.id == id &&
      other.productId == productId &&
      other.barcode == barcode &&
      other.brand == brand &&
      other.size == size &&
      other.unit == unit &&
      other.origin == origin &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(id, productId, barcode, brand, size, unit, origin, createdAt, updatedAt);

  @override
  String toString() => 'ProductPackage($id, $productId, $label)';
}
