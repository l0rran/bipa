import 'package:bipa/core/money/money.dart';
import 'package:bipa/features/prices/domain/price_condition.dart';
import 'package:bipa/features/prices/domain/price_observation.dart';
import 'package:bipa/features/prices/domain/price_source.dart';
import 'package:bipa/features/prices/domain/price_trend.dart';
import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:bipa/features/products/domain/product_package.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 10, 28, 18);

ProductPackage _package(String id, double? size, {MeasureUnit unit = MeasureUnit.kilogram}) =>
    ProductPackage(id: id, productId: 'arroz', size: size, unit: unit, createdAt: _now, updatedAt: _now);

var _seq = 0;

PriceHistoryEntry _price(
  String? package,
  int cents,
  DateTime at, {
  String market = 'vila',
  PriceCondition condition = const AnyCustomer(),
}) => PriceHistoryEntry(
  observation: PriceObservation(
    id: 'o${_seq++}',
    productId: 'arroz',
    packageId: package,
    marketId: market,
    price: Money.cents(cents),
    source: PriceSource.priceTag,
    condition: condition,
    observedAt: at,
    createdAt: at,
  ),
  marketName: market,
);

List<(DateTime, int)> _points(PriceTrend trend) => [for (final p in trend.points) (p.day, p.price.cents)];

void main() {
  final packages = [_package('tio-joao', 5), _package('camil', 10)];

  test('compara embalagens pelo preço por kg, com o menor preço de cada dia', () {
    final trend = priceTrend(
      [
        _price('tio-joao', 2790, DateTime(2026, 9, 2, 10)), // R$ 5,58/kg
        _price('camil', 4990, DateTime(2026, 9, 2, 11), market: 'centro'), // R$ 4,99/kg
        _price('tio-joao', 2990, DateTime(2026, 10, 20)), // R$ 5,98/kg
      ],
      packages,
      now: _now,
    )!;

    expect(trend.unit, MeasureUnit.kilogram);
    expect(_points(trend), [(DateTime(2026, 9, 2), 499), (DateTime(2026, 10, 20), 598)]);
    expect((trend.lowest.cents, trend.highest.cents), (499, 598));
  });

  test('o período começa no primeiro dia do mês, seis meses contando o atual', () {
    final trend = priceTrend(
      [
        _price('camil', 5000, DateTime(2026, 4, 30)), // antes de maio: fica de fora
        _price('camil', 5200, DateTime(2026, 5, 1)),
        _price('camil', 4990, DateTime(2026, 10, 1)),
      ],
      packages,
      now: _now,
    )!;

    expect(trend.from, DateTime(2026, 5));
    expect(trend.points.map((p) => p.day), [DateTime(2026, 5, 1), DateTime(2026, 10, 1)]);
  });

  test('cartão e atacado não entram', () {
    final trend = priceTrend(
      [
        _price('camil', 4990, DateTime(2026, 9, 1)),
        _price('camil', 3990, DateTime(2026, 9, 1), condition: const LoyaltyMembers()),
        _price('camil', 4590, DateTime(2026, 10, 1)),
        _price('camil', 4290, DateTime(2026, 10, 1), condition: const Wholesale(minimumQuantity: 3)),
      ],
      packages,
      now: _now,
    );

    expect(_points(trend!), [(DateTime(2026, 9, 1), 499), (DateTime(2026, 10, 1), 459)]);
  });

  test('sem tamanho, usa o preço da embalagem quando ela é uma só', () {
    final trend = priceTrend(
      [_price('granel', 600, DateTime(2026, 9, 1)), _price('granel', 650, DateTime(2026, 10, 1))],
      [_package('granel', null)],
      now: _now,
    );

    expect(trend?.unit, isNull);
    expect(_points(trend!), [(DateTime(2026, 9, 1), 600), (DateTime(2026, 10, 1), 650)]);
  });

  test('sem tendência com um dia só ou com embalagens sem tamanho diferentes', () {
    expect(priceTrend([_price('camil', 4990, DateTime(2026, 9, 1))], packages, now: _now), isNull);
    expect(
      priceTrend(
        [_price('a', 600, DateTime(2026, 9, 1)), _price('b', 900, DateTime(2026, 10, 1))],
        [_package('a', null), _package('b', null)],
        now: _now,
      ),
      isNull,
    );
  });

  test('com kg e L, fica a grandeza com mais preços', () {
    final trend = priceTrend(
      [
        _price('camil', 4990, DateTime(2026, 9, 1)),
        _price('camil', 4590, DateTime(2026, 10, 1)),
        _price('garrafa', 900, DateTime(2026, 10, 2)),
      ],
      [...packages, _package('garrafa', 1, unit: MeasureUnit.liter)],
      now: _now,
    );

    expect(trend?.unit, MeasureUnit.kilogram);
    expect(trend?.points, hasLength(2));
  });
}
