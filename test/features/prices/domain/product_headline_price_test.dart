import 'package:bipa/core/money/money.dart';
import 'package:bipa/features/prices/domain/price_observation.dart';
import 'package:bipa/features/prices/domain/price_source.dart';
import 'package:bipa/features/prices/domain/product_headline_price.dart';
import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/products/domain/product_package.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 10, 28);

Product _product(MeasureUnit unit) =>
    Product(id: 'arroz', name: 'Arroz branco', unit: unit, createdAt: _now, updatedAt: _now);

ProductPackage _package(String id, double? size, {MeasureUnit unit = MeasureUnit.kilogram}) =>
    ProductPackage(id: id, productId: 'arroz', brand: id, size: size, unit: unit, createdAt: _now, updatedAt: _now);

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
  final kilo = _product(MeasureUnit.kilogram);

  test('uma embalagem: o preço dela, o menor entre os mercados, sem "por unidade"', () {
    final price = headlinePrice(
      product: kilo,
      packages: [_package('tio-joao', 5)],
      history: [_price('vila', 'tio-joao', 2790), _price('centro', 'tio-joao', 2490)],
    );

    expect(price, (price: const Money.cents(2490), perUnit: null));
  });

  test('uma embalagem: vale o preço mais recente de cada mercado, não o menor de todos', () {
    final price = headlinePrice(
      product: kilo,
      packages: [_package('tio-joao', 5)],
      history: [_price('vila', 'tio-joao', 2000, day: 1), _price('vila', 'tio-joao', 2790, day: 2)],
    );

    expect(price?.price, const Money.cents(2790));
  });

  test('várias embalagens: o menor preço por kg', () {
    final price = headlinePrice(
      product: kilo,
      packages: [_package('tio-joao', 5), _package('camil', 10)],
      history: [_price('vila', 'tio-joao', 2790), _price('vila', 'camil', 4990)],
    );

    // 49,90 / 10 kg = 4,99 o kg, contra 5,58 do pacote de 5 kg.
    expect(price, (price: const Money.cents(499), perUnit: MeasureUnit.kilogram));
  });

  test('várias embalagens em gramas: o preço é normalizado para o kg', () {
    final price = headlinePrice(
      product: kilo,
      packages: [
        _package('pilao', 500, unit: MeasureUnit.gram),
        _package('melitta', 250, unit: MeasureUnit.gram),
      ],
      history: [_price('vila', 'pilao', 1899), _price('vila', 'melitta', 1100)],
    );

    // 18,99 / 0,5 kg = 37,98 o kg; 11,00 / 0,25 kg = 44,00 o kg.
    expect(price, (price: const Money.cents(3798), perUnit: MeasureUnit.kilogram));
  });

  test('várias embalagens: só uma com tamanho e preço ainda dá o preço por kg dela', () {
    final price = headlinePrice(
      product: kilo,
      packages: [_package('tio-joao', 5), _package('sem-tamanho', null)],
      history: [_price('vila', 'tio-joao', 2790), _price('vila', 'sem-tamanho', 100)],
    );

    expect(price, (price: const Money.cents(558), perUnit: MeasureUnit.kilogram));
  });

  test('várias embalagens, nenhuma com tamanho: sem preço, que não seria comparável', () {
    final price = headlinePrice(
      product: kilo,
      packages: [_package('a', null), _package('b', null)],
      history: [_price('vila', 'a', 500), _price('vila', 'b', 900)],
    );

    expect(price, isNull);
  });

  test('várias embalagens: prefere a unidade do produto a outra', () {
    final price = headlinePrice(
      product: _product(MeasureUnit.liter),
      packages: [
        _package('leite', 1, unit: MeasureUnit.liter),
        _package('ovos', 12, unit: MeasureUnit.unit),
      ],
      history: [_price('vila', 'leite', 549), _price('vila', 'ovos', 1200)],
    );

    expect(price, (price: const Money.cents(549), perUnit: MeasureUnit.liter));
  });

  test('sem embalagem (granel): o menor preço sem embalagem, por kg', () {
    final price = headlinePrice(
      product: kilo,
      packages: const [],
      history: [_price('vila', null, 899), _price('centro', null, 999)],
    );

    expect(price, (price: const Money.cents(899), perUnit: MeasureUnit.kilogram));
  });

  test('sem preço nenhum: nulo', () {
    expect(headlinePrice(product: kilo, packages: const [], history: const []), isNull);
    expect(headlinePrice(product: kilo, packages: [_package('a', 1)], history: const []), isNull);
  });

  test('preço de outra embalagem não conta para a embalagem única', () {
    final price = headlinePrice(
      product: kilo,
      packages: [_package('a', 1)],
      history: [_price('vila', 'apagada', 100), _price('vila', null, 200)],
    );

    expect(price, isNull);
  });
}
