import 'package:bipa/core/money/money.dart';
import 'package:bipa/features/prices/domain/package_prices.dart';
import 'package:bipa/features/prices/domain/price_observation.dart';
import 'package:bipa/features/prices/domain/price_source.dart';
import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:bipa/features/products/domain/product_package.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 10, 28);

ProductPackage _package(String id, double? size) => ProductPackage(
  id: id,
  productId: 'arroz',
  brand: id,
  size: size,
  unit: MeasureUnit.kilogram,
  createdAt: _now,
  updatedAt: _now,
);

var _seq = 0;

PriceHistoryEntry _price(String market, String? package, int cents, {int day = 1}) => PriceHistoryEntry(
  observation: PriceObservation(
    id: 'o${_seq++}',
    productId: 'arroz',
    packageId: package,
    marketId: market,
    price: Money.cents(cents),
    source: PriceSource.manual,
    observedAt: DateTime(2026, 10, day),
    createdAt: DateTime(2026, 10, day),
  ),
  marketName: market,
);

void main() {
  final packages = [_package('tio-joao', 5), _package('camil', 10), _package('granel', null)];

  test('cada embalagem com o preço mais recente, da mais barata por kg para a mais cara', () {
    final history = [
      _price('vila', 'tio-joao', 2790),
      _price('centro', 'tio-joao', 2990),
      _price('vila', 'camil', 5290, day: 1),
      _price('vila', 'camil', 4990, day: 2),
      _price('vila', 'granel', 600),
    ];

    final prices = latestPricePerPackage(history, packages);

    expect(prices.map((p) => (p.package?.id, p.price.cents)), [('camil', 4990), ('tio-joao', 2790), ('granel', 600)]);
    expect(prices.first.unitPrice?.price, const Money.cents(499));
  });

  test('em cada mercado, a embalagem mais barata por kg', () {
    final history = [
      _price('vila', 'tio-joao', 2790),
      _price('vila', 'camil', 4990),
      _price('centro', 'tio-joao', 2645),
    ];

    final best = bestPricePerMarket(history, packages);

    expect(best.map((p) => (p.entry.marketName, p.package?.id, p.unitPrice?.price.cents)), [
      ('vila', 'camil', 499),
      ('centro', 'tio-joao', 529),
    ]);
  });

  test('preços sem embalagem também entram na comparação entre mercados', () {
    final best = bestPricePerMarket([_price('feira', null, 500)], packages);

    expect(best.single.package, isNull);
    expect(best.single.unitPrice, isNull);
  });
}
