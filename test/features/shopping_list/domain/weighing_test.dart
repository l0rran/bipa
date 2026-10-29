import 'package:bipa/core/money/money.dart';
import 'package:bipa/features/prices/domain/price_source.dart';
import 'package:bipa/features/shopping_list/domain/trip_price.dart';
import 'package:bipa/features/shopping_list/domain/weighing.dart';
import 'package:flutter_test/flutter_test.dart';

TripPrice _price(String productId, int cents, {String? packageId, bool perKilo = false}) => TripPrice(
  tripId: 'trip',
  productId: productId,
  packageId: packageId,
  price: Money.cents(cents),
  source: PriceSource.priceTag,
  readAt: DateTime(2026, 10, 28),
  perKilo: perKilo,
);

void main() {
  group('weightInGrams', () {
    test('R\$ 12,40 a R\$ 8,99/kg dá 1.379 g (o quadro: 1,38 kg)', () {
      expect(weightInGrams(const Money.cents(1240), const Money.cents(899)), 1379);
    });

    test('um preço que paga um número exato de quilos', () {
      expect(weightInGrams(const Money.cents(1798), const Money.cents(899)), 2000);
      expect(weightInGrams(const Money.cents(899), const Money.cents(899)), 1000);
    });

    test('arredonda ao grama mais próximo, e o meio grama sobe', () {
      // 100 * 1000 / 300 = 333,33 g; 200 * 1000 / 300 = 666,67 g.
      expect(weightInGrams(const Money.cents(100), const Money.cents(300)), 333);
      expect(weightInGrams(const Money.cents(200), const Money.cents(300)), 667);
      // 1 * 1000 / 400 = 2,5 g: o meio grama sobe.
      expect(weightInGrams(const Money.cents(1), const Money.cents(400)), 3);
    });

    test('a conta é em inteiros: valores grandes não perdem centavos', () {
      // R$ 99.999,99 a R$ 0,01/kg: 9.999.999 kg, sem a deriva de um double.
      expect(weightInGrams(const Money.cents(9999999), const Money.cents(1)), 9999999000);
    });

    test('sem conta a fazer devolve null', () {
      expect(weightInGrams(Money.zero, const Money.cents(899)), isNull);
      expect(weightInGrams(const Money.cents(1240), Money.zero), isNull);
      expect(weightInGrams(const Money.cents(-1240), const Money.cents(899)), isNull);
      // Menos de um grama.
      expect(weightInGrams(const Money.cents(1), const Money.cents(1000000)), isNull);
    });
  });

  group('formatWeight', () {
    test('a partir de um quilo, kg com duas casas e vírgula', () {
      expect(formatWeight(1379), '1,38 kg');
      expect(formatWeight(1000), '1,00 kg');
      expect(formatWeight(2005), '2,01 kg');
      expect(formatWeight(12340), '12,34 kg');
    });

    test('abaixo de um quilo, gramas', () {
      expect(formatWeight(450), '450 g');
      expect(formatWeight(999), '999 g');
    });
  });

  group('preços da compra do granel', () {
    final prices = [
      _price('tomate', 899, perKilo: true),
      _price('cenoura', 450),
      _price('leite', 599, packageId: 'caixa'),
      _price('cenoura', 790, perKilo: true),
    ];

    test('perKiloPriceOf acha o preço por quilo do produto', () {
      expect(perKiloPriceOf(prices, 'tomate'), const Money.cents(899));
      expect(perKiloPriceOf(prices, 'cenoura'), const Money.cents(790));
    });

    test('perKiloPriceOf não confunde com o preço de gôndola nem o de embalagem', () {
      expect(perKiloPriceOf(prices, 'leite'), isNull);
      expect(perKiloPriceOf(prices, 'banana'), isNull);
    });

    test('shelfPriceOf acha só o preço de gôndola da linha sem embalagem', () {
      expect(shelfPriceOf(prices, 'cenoura')?.price, const Money.cents(450));
      expect(shelfPriceOf(prices, 'tomate'), isNull);
      expect(shelfPriceOf(prices, 'leite'), isNull);
    });

    test('só a linha sem preço de gôndola é pesagem', () {
      expect(isWeighingLine(packageId: null, shelfPrice: shelfPriceOf(prices, 'tomate')), isTrue);
      expect(isWeighingLine(packageId: null, shelfPrice: shelfPriceOf(prices, 'cenoura')), isFalse);
      expect(isWeighingLine(packageId: 'caixa', shelfPrice: null), isFalse);
    });
  });
}
