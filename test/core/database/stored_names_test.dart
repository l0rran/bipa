import 'package:bipa/core/catalog/product_kind.dart';
import 'package:bipa/core/database/price_offers_converter.dart';
import 'package:bipa/core/money/money.dart';
import 'package:bipa/features/prices/domain/price_condition.dart';
import 'package:bipa/features/prices/domain/price_source.dart';
import 'package:bipa/features/prices/domain/price_tag.dart';
import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:bipa/features/products/domain/package_origin.dart';
import 'package:bipa/features/stock/domain/stock_location.dart';
import 'package:bipa/features/stock/domain/stock_movement_reason.dart';
import 'package:flutter_test/flutter_test.dart';

/// Os nomes que o banco grava fazem parte do formato do backup (ADR 0023,
/// lacuna B4). Se um teste daqui falhar, um nome gravado mudou: volte o nome
/// ou escreva a migração que reescreve as linhas, e só então atualize a
/// lista. Acrescentar um valor novo não exige migração e não quebra estes
/// testes.
void main() {
  List<String> names(List<Enum> values) => [for (final value in values) value.name];

  test('as unidades: products.unit e product_packages.unit', () {
    expect(names(MeasureUnit.values), containsAll(['unit', 'gram', 'kilogram', 'milliliter', 'liter']));
  });

  test('a origem da embalagem: product_packages.origin', () {
    // `person` é também o padrão da coluna, para as embalagens anteriores
    // ao esquema 15.
    expect(
      names(PackageOrigin.values),
      containsAll(['person', 'openFoodFacts', 'openProductsFacts', 'openBeautyFacts']),
    );
  });

  test('as condições do preço: price_observations.condition_kind', () {
    expect(names(PriceConditionKind.values), containsAll(['anyCustomer', 'loyaltyMembers', 'wholesale']));
  });

  test('as origens do preço: price_observations.source e trip_prices.source', () {
    expect(names(PriceSource.values), containsAll(['manual', 'priceTag', 'receipt']));
  });

  test('os locais em casa: stock_items.location e remembered_locations.location', () {
    expect(names(StockLocation.values), containsAll(['pantry', 'fridge', 'freezer', 'bathroom', 'cleaning', 'other']));
  });

  test('os motivos do movimento: stock_movements.reason', () {
    expect(names(StockMovementReason.values), containsAll(['purchase', 'consumption', 'adjustment']));
  });

  test('as seções do mercado: market_aisles.aisle', () {
    expect(
      names(Aisle.values),
      containsAll([
        'produce',
        'bakery',
        'meat',
        'dairy',
        'grocery',
        'sweets',
        'frozen',
        'drinks',
        'cleaning',
        'hygiene',
        'pet',
        'other',
      ]),
    );
  });

  group('o JSON de trip_prices.other_offers', () {
    const converter = PriceOffersConverter();

    test('grava as chaves de sempre', () {
      const offers = [
        PriceOffer(price: Money.cents(499), condition: LoyaltyMembers()),
        PriceOffer(price: Money.cents(459), condition: Wholesale(minimumQuantity: 3), regularPrice: Money.cents(549)),
      ];

      expect(
        converter.toSql(offers),
        '[{"cents":499,"condition":"loyaltyMembers"},'
        '{"cents":459,"condition":"wholesale","minimumQuantity":3,"regularCents":549}]',
      );
    });

    test('lê o que uma versão anterior gravou', () {
      const stored =
          '[{"cents":499,"condition":"loyaltyMembers"},'
          '{"cents":459,"condition":"wholesale","minimumQuantity":3,"regularCents":549},'
          '{"cents":429,"condition":"anyCustomer"}]';

      expect(converter.fromSql(stored), const [
        PriceOffer(price: Money.cents(499), condition: LoyaltyMembers()),
        PriceOffer(price: Money.cents(459), condition: Wholesale(minimumQuantity: 3), regularPrice: Money.cents(549)),
        PriceOffer(price: Money.cents(429)),
      ]);
    });
  });
}
