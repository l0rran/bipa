import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:meta/meta.dart';

/// O que se usa em casa: "Arroz branco", "Café". Estoque, lista e "ter
/// sempre" ficam no produto; marca, tamanho e código de barras ficam em cada
/// uma das suas embalagens (ADR 0013).
@immutable
final class Product {
  const Product({
    required this.id,
    required this.name,
    required this.unit,
    required this.createdAt,
    required this.updatedAt,
    this.photoPath,
  });

  final String id;
  final String name;

  /// Unidade em que o produto se mede (kg para o arroz, un para ovos): a
  /// sugerida para as embalagens novas e a do total em casa.
  final MeasureUnit unit;

  /// Foto do produto guardada no aparelho, relativa à pasta de fotos do app.
  /// Sem foto, a interface mostra o ícone da categoria.
  final String? photoPath;
  final DateTime createdAt;
  final DateTime updatedAt;

  Product copyWith({String? name, MeasureUnit? unit, String? photoPath, DateTime? updatedAt}) => Product(
    id: id,
    name: name ?? this.name,
    unit: unit ?? this.unit,
    photoPath: photoPath ?? this.photoPath,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  bool operator ==(Object other) =>
      other is Product &&
      other.id == id &&
      other.name == name &&
      other.unit == unit &&
      other.photoPath == photoPath &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(id, name, unit, photoPath, createdAt, updatedAt);

  @override
  String toString() => 'Product($id, $name)';
}
