import 'package:bipa/core/database/price_offers_converter.dart';
import 'package:bipa/core/money/money.dart';
import 'package:bipa/features/prices/domain/price_condition.dart';
import 'package:bipa/features/prices/domain/price_tag.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const converter = PriceOffersConverter();

  test('os outros preços da etiqueta voltam iguais', () {
    const offers = [
      PriceOffer(price: Money.cents(499), condition: LoyaltyMembers()),
      PriceOffer(price: Money.cents(459), condition: Wholesale(minimumQuantity: 3)),
      PriceOffer(price: Money.cents(429), condition: Wholesale()),
      PriceOffer(price: Money.cents(549), regularPrice: Money.cents(649)),
    ];

    expect(converter.fromSql(converter.toSql(offers)), offers);
  });

  test('sem outros preços, a lista vazia', () {
    expect(converter.toSql(const []), '[]');
    expect(converter.fromSql('[]'), isEmpty);
  });
}
