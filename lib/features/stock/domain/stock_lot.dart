import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:bipa/features/products/domain/product_package.dart';
import 'package:meta/meta.dart';

/// O que entrou em casa numa compra (ADR 0013): quantas unidades, de qual
/// embalagem e quando. A soma dos lotes de um produto é a quantidade dele em
/// casa.
@immutable
final class StockLot {
  const StockLot({
    required this.id,
    required this.productId,
    required this.quantity,
    required this.since,
    this.packageId,
    this.package,
  });

  final String id;
  final String productId;

  /// `null` quando o produto não tinha embalagem (ou ela foi apagada).
  final String? packageId;

  /// A embalagem, quando lida junto do lote para mostrar na tela.
  final ProductPackage? package;
  final double quantity;
  final DateTime since;

  @override
  bool operator ==(Object other) =>
      other is StockLot &&
      other.id == id &&
      other.productId == productId &&
      other.packageId == packageId &&
      other.package == package &&
      other.quantity == quantity &&
      other.since == since;

  @override
  int get hashCode => Object.hash(id, productId, packageId, package, quantity, since);
}

/// Quanto um lote mudou num ajuste.
@immutable
final class StockLotDelta {
  const StockLotDelta({required this.lotId, required this.delta, required this.since, this.packageId});

  final String lotId;
  final String? packageId;

  /// Quando o lote entrou em casa, para recriá-lo igual se o desfazer
  /// precisar devolvê-lo.
  final DateTime since;
  final double delta;

  @override
  bool operator ==(Object other) =>
      other is StockLotDelta &&
      other.lotId == lotId &&
      other.packageId == packageId &&
      other.since == since &&
      other.delta == delta;

  @override
  int get hashCode => Object.hash(lotId, packageId, since, delta);
}

/// O que um ajuste de estoque mudou de fato, lote a lote. É o que o
/// "Desfazer" reverte: tira exatamente o lote que entrou e devolve
/// exatamente os lotes que saíram.
@immutable
final class StockChange {
  const StockChange({required this.productId, this.lots = const []});

  final String productId;
  final List<StockLotDelta> lots;

  /// Quanto a quantidade do produto mudou.
  double get applied => lots.fold(0.0, (sum, lot) => sum + lot.delta);

  bool get isEmpty => lots.isEmpty;

  @override
  bool operator ==(Object other) => other is StockChange && other.productId == productId && _sameLots(other.lots, lots);

  @override
  int get hashCode => Object.hash(productId, Object.hashAll(lots));

  static bool _sameLots(List<StockLotDelta> a, List<StockLotDelta> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Quanto sai de cada lote para tirar [amount] de casa: primeiro dos lotes
/// de [packageId] (quando informada), depois do que está em casa há mais
/// tempo. Tira no máximo o que há.
List<({StockLot lot, double taken})> takeFromLots(List<StockLot> lots, double amount, {String? packageId}) {
  final ordered =
      [
        for (final lot in lots)
          if (lot.quantity > 0) lot,
      ]..sort((a, b) {
        if (packageId != null) {
          final preferred = (b.packageId == packageId ? 1 : 0) - (a.packageId == packageId ? 1 : 0);
          if (preferred != 0) return preferred;
        }
        final bySince = a.since.compareTo(b.since);
        return bySince != 0 ? bySince : a.id.compareTo(b.id);
      });
  final plan = <({StockLot lot, double taken})>[];
  var remaining = amount;
  for (final lot in ordered) {
    if (remaining <= _epsilon) break;
    final taken = remaining < lot.quantity ? remaining : lot.quantity;
    plan.add((lot: lot, taken: taken));
    remaining -= taken;
  }
  return plan;
}

/// Quanto há em casa somando os lotes: 1 de 5 kg e 1 de 10 kg dão 15 kg.
///
/// Só vale quando todo lote tem embalagem com tamanho, na mesma grandeza
/// (peso, volume ou unidades); senão, `null`, e a interface mostra só a
/// contagem.
({double amount, MeasureUnit unit})? homeAmount(List<StockLot> lots) {
  var amount = 0.0;
  MeasureUnit? unit;
  for (final lot in lots) {
    if (lot.quantity <= 0) continue;
    final package = lot.package;
    final size = package?.sizeInBaseUnit;
    if (package == null || size == null) return null;
    final base = package.unit.baseUnit;
    if (unit != null && unit != base) return null;
    unit = base;
    amount += size * lot.quantity;
  }
  if (unit == null) return null;
  // Menos de 1 kg (ou 1 L) fica em g (ou ml), que é como se fala.
  return switch (unit) {
    MeasureUnit.kilogram when amount < 1 => (amount: amount * 1000, unit: MeasureUnit.gram),
    MeasureUnit.liter when amount < 1 => (amount: amount * 1000, unit: MeasureUnit.milliliter),
    _ => (amount: amount, unit: unit),
  };
}

const _epsilon = 1e-9;
