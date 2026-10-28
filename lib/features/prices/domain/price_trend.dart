import 'package:bipa/core/money/money.dart';
import 'package:bipa/features/prices/domain/price_condition.dart';
import 'package:bipa/features/prices/domain/price_observation.dart';
import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:bipa/features/products/domain/product_package.dart';
import 'package:meta/meta.dart';

/// Um dia no gráfico: o menor preço visto nele.
@immutable
final class PricePoint {
  const PricePoint({required this.day, required this.price});

  /// O dia, à meia-noite.
  final DateTime day;
  final Money price;

  @override
  bool operator ==(Object other) => other is PricePoint && other.day == day && other.price == price;

  @override
  int get hashCode => Object.hash(day, price);

  @override
  String toString() => 'PricePoint($day, $price)';
}

/// Como o preço de um produto andou: um ponto por dia com preço, do mais
/// antigo para o mais recente, entre [from] e [to].
@immutable
final class PriceTrend {
  const PriceTrend({required this.points, required this.from, required this.to, this.unit});

  final List<PricePoint> points;

  /// Por kg, L ou un quando os preços vêm do tamanho das embalagens; `null`
  /// quando são preços de uma embalagem só, sem tamanho.
  final MeasureUnit? unit;

  /// O começo do período: o primeiro dia do mês mais antigo.
  final DateTime from;
  final DateTime to;

  Money get lowest => points.map((p) => p.price).reduce((a, b) => a < b ? a : b);

  Money get highest => points.map((p) => p.price).reduce((a, b) => a < b ? b : a);

  @override
  bool operator ==(Object other) =>
      other is PriceTrend &&
      other.unit == unit &&
      other.from == from &&
      other.to == to &&
      _samePoints(other.points, points);

  @override
  int get hashCode => Object.hash(unit, from, to, Object.hashAll(points));

  static bool _samePoints(List<PricePoint> a, List<PricePoint> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// O preço do produto nos últimos [months] meses, contando o atual: o menor
/// preço de cada dia, em qualquer mercado.
///
/// * Vale o preço sem condição (ADR 0011): cartão e atacado não entram.
/// * Embalagens diferentes se comparam pelo preço por kg (ADR 0013), na
///   grandeza da maioria dos preços (um produto com kg e L fica com a que
///   tem mais preços).
/// * Sem tamanho em nenhuma embalagem, vale o preço da embalagem, desde que
///   seja uma só; embalagens diferentes sem tamanho não se comparam.
///
/// Devolve `null` com menos de dois dias de preço: um ponto não é tendência.
PriceTrend? priceTrend(
  Iterable<PriceHistoryEntry> history,
  List<ProductPackage> packages, {
  required DateTime now,
  int months = 6,
}) {
  assert(months > 0);
  final from = DateTime(now.year, now.month - (months - 1));
  final byId = {for (final package in packages) package.id: package};
  final observations = [
    for (final entry in history)
      if (entry.observation case final observation
          when observation.condition is AnyCustomer &&
              !observation.observedAt.isBefore(from) &&
              !observation.observedAt.isAfter(now))
        observation,
  ];

  // Preço por kg (ou L, ou un), agrupado pela grandeza.
  final byUnit = <MeasureUnit, List<(DateTime, Money)>>{};
  for (final observation in observations) {
    final unitPrice = byId[observation.packageId]?.unitPrice(observation.price);
    if (unitPrice != null) {
      byUnit.putIfAbsent(unitPrice.unit, () => []).add((observation.observedAt, unitPrice.price));
    }
  }

  final MeasureUnit? unit;
  final List<(DateTime, Money)> prices;
  if (byUnit.isNotEmpty) {
    final main = byUnit.entries.reduce((a, b) => b.value.length > a.value.length ? b : a);
    unit = main.key;
    prices = main.value;
  } else {
    final packageIds = {for (final observation in observations) observation.packageId};
    if (packageIds.length != 1) return null;
    unit = null;
    prices = [for (final observation in observations) (observation.observedAt, observation.price)];
  }

  final lowestByDay = <DateTime, Money>{};
  for (final (at, price) in prices) {
    final day = DateTime(at.year, at.month, at.day);
    final current = lowestByDay[day];
    if (current == null || price < current) lowestByDay[day] = price;
  }
  if (lowestByDay.length < 2) return null;

  final points = [
    for (final MapEntry(key: day, value: price) in lowestByDay.entries) PricePoint(day: day, price: price),
  ]..sort((a, b) => a.day.compareTo(b.day));
  return PriceTrend(points: points, unit: unit, from: from, to: now);
}
