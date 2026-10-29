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

  group('kg e litro não se comparam (G16)', () {
    // O "Leite" com o UHT de 1 L e o leite em pó de 400 g, movido para ele.
    ProductPackage milkPackage(String id, double size, MeasureUnit unit, {required int day}) => ProductPackage(
      id: id,
      productId: 'arroz',
      size: size,
      unit: unit,
      createdAt: DateTime(2026, 10, day),
      updatedAt: DateTime(2026, 10, day),
    );
    final uht = milkPackage('uht', 1, MeasureUnit.liter, day: 1);
    final powder = milkPackage('po', 400, MeasureUnit.gram, day: 2);
    final milk = [uht, powder];

    test('o destaque fica na grandeza da maioria dos preços, mesmo mais cara', () {
      final history = [_price('a', 'uht', 549), _price('c', 'uht', 579), _price('b', 'po', 2190)];

      expect(mainPriceUnit(history, milk), MeasureUnit.liter);
      final prices = latestPricePerPackage(history, milk);
      expect(prices.map((p) => (p.unitPrice?.price.cents, p.unitPrice?.unit)), [
        (549, MeasureUnit.liter),
        (5475, MeasureUnit.kilogram),
      ]);
      // Uma embalagem só por litro: não há "menor por litro" a mostrar.
      expect(firstIsCheapest(prices), isFalse);
    });

    test('num empate, vale a grandeza da embalagem mais recente', () {
      final history = [_price('a', 'uht', 549), _price('b', 'po', 2190)];

      expect(mainPriceUnit(history, milk), MeasureUnit.kilogram);
      expect(latestPricePerPackage(history, milk).first.package, powder);
      // Com o UHT mais recente, o litro vence.
      final newerUht = milkPackage('uht', 1, MeasureUnit.liter, day: 3);
      expect(mainPriceUnit(history, [newerUht, powder]), MeasureUnit.liter);
    });

    test('o "Mais barato" compara só os mercados da mesma grandeza', () {
      final history = [_price('a', 'uht', 549), _price('c', 'uht', 579), _price('b', 'po', 2190)];

      final best = bestPricePerMarket(history, milk);

      expect(best.map((p) => p.entry.marketName), ['a', 'c', 'b']);
      expect(firstIsCheapest(best), isTrue);
      expect(firstIsCheapest(bestPricePerMarket([_price('a', 'uht', 549), _price('b', 'po', 2190)], milk)), isFalse);
    });

    test('num mercado com as duas, fica a da grandeza principal', () {
      final history = [_price('a', 'uht', 549), _price('a', 'po', 2190), _price('c', 'uht', 579)];

      final best = bestPricePerMarket(history, milk);

      expect(best.map((p) => (p.entry.marketName, p.package?.id)), [('a', 'uht'), ('c', 'uht')]);
    });

    test('sem preço com tamanho, não há grandeza principal', () {
      expect(mainPriceUnit([_price('feira', null, 500), _price('a', 'granel', 600)], packages), isNull);
    });
  });
}
