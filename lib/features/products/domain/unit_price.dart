import 'package:bipa/core/money/money.dart';
import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:meta/meta.dart';

/// Preço normalizado por unidade base (R$/kg, R$/L ou R$/un).
///
/// Permite comparar embalagens de tamanhos diferentes, como 395 g e 1 kg.
@immutable
final class UnitPrice {
  const UnitPrice({required this.price, required this.unit});

  final Money price;

  /// Sempre uma unidade base: quilo, litro ou unidade.
  final MeasureUnit unit;

  /// Calcula o preço por unidade base de uma embalagem.
  ///
  /// Retorna `null` quando o tamanho da embalagem não é conhecido.
  static UnitPrice? of({
    required Money price,
    required double? packageSize,
    required MeasureUnit unit,
  }) {
    if (packageSize == null || packageSize <= 0) return null;
    final quantityInBaseUnit = packageSize * unit.toBaseFactor;
    return UnitPrice(
      price: Money.cents((price.cents / quantityInBaseUnit).round()),
      unit: unit.baseUnit,
    );
  }

  /// Ex.: `R$ 20,23/kg`.
  String format() => '${price.format()}/${unit.symbol}';

  @override
  bool operator ==(Object other) =>
      other is UnitPrice && other.price == price && other.unit == unit;

  @override
  int get hashCode => Object.hash(price, unit);

  @override
  String toString() => 'UnitPrice(${format()})';
}
