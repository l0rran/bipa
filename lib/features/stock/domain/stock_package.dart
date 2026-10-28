import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:bipa/features/products/domain/product_package.dart';
import 'package:meta/meta.dart';

/// Quantas embalagens de um tipo há em casa (ADR 0013).
@immutable
final class StockPackageCount {
  const StockPackageCount({required this.package, required this.quantity, required this.since});

  final ProductPackage package;
  final double quantity;

  /// Quando essa embalagem entrou em casa.
  final DateTime since;

  @override
  bool operator ==(Object other) =>
      other is StockPackageCount && other.package == package && other.quantity == quantity && other.since == since;

  @override
  int get hashCode => Object.hash(package, quantity, since);
}

/// Quanto há em casa somando as embalagens: 1 de 5 kg e 1 de 10 kg dão 15 kg.
///
/// Só vale quando todas as [quantity] embalagens do produto estão contadas
/// em [counts], com tamanho e na mesma grandeza (peso, volume ou unidades);
/// senão, `null`, e a interface mostra só a contagem.
({double amount, MeasureUnit unit})? homeAmount(List<StockPackageCount> counts, {required double quantity}) {
  if (quantity <= 0 || counts.isEmpty) return null;
  var counted = 0.0;
  var amount = 0.0;
  MeasureUnit? unit;
  for (final count in counts) {
    final size = count.package.sizeInBaseUnit;
    final base = count.package.unit.baseUnit;
    if (size == null || (unit != null && unit != base)) return null;
    unit = base;
    counted += count.quantity;
    amount += size * count.quantity;
  }
  if (unit == null || (counted - quantity).abs() > 1e-9) return null;
  // Menos de 1 kg (ou 1 L) fica em g (ou ml), que é como se fala.
  return switch (unit) {
    MeasureUnit.kilogram when amount < 1 => (amount: amount * 1000, unit: MeasureUnit.gram),
    MeasureUnit.liter when amount < 1 => (amount: amount * 1000, unit: MeasureUnit.milliliter),
    _ => (amount: amount, unit: unit),
  };
}
