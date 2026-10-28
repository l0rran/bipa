import 'package:bipa/core/money/money.dart';
import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/shopping_list/domain/cart_item.dart';
import 'package:bipa/features/shopping_list/domain/shopping_list_item.dart';
import 'package:bipa/features/shopping_list/domain/trip_review.dart';
import 'package:flutter_test/flutter_test.dart';

final _at = DateTime(2026, 10, 28, 10);

CartEntry _cart(String id, {int? cents, int quantity = 1, bool take = true, bool estimated = false}) => CartEntry(
  item: CartItem(
    id: id,
    tripId: 'compra',
    productId: id,
    addedAt: _at,
    quantity: quantity,
    price: cents == null ? null : Money.cents(cents),
    priceEstimated: estimated,
    take: take,
  ),
  product: Product(id: id, name: id, unit: MeasureUnit.unit, createdAt: _at, updatedAt: _at),
);

ShoppingListEntry _listed(String id, {bool checked = false, int quantity = 1}) => ShoppingListEntry(
  item: ShoppingListItem(
    id: 'l-$id',
    productId: id,
    name: id,
    addedAt: _at,
    checkedAt: checked ? _at : null,
    quantity: quantity,
  ),
);

void main() {
  test('soma o carrinho para levar e conta as embalagens, com as marcadas à mão', () {
    final review = TripReview.of(
      entries: [_listed('leite', checked: true, quantity: 2), _listed('arroz'), _listed('cafe', checked: true)],
      cart: [
        _cart('cafe', cents: 1899, quantity: 2),
        _cart('pao', estimated: true, cents: 700),
        _cart('sabao'),
        _cart('vinho', cents: 5000, take: false),
      ],
    );

    expect(review.spent, const Money.cents(1899 * 2 + 700));
    expect(review.estimated, isTrue);
    // O sabão do carrinho e o leite marcado à mão, sem preço esperado.
    expect(review.unpriced, 2);
    // Café (2), pão e sabão do carrinho, mais o leite marcado à mão (2).
    expect(review.packages, 6);
    expect(review.missing, [(name: 'arroz', quantity: 1)]);
  });

  test('a economia compara a mesma cesta, com as quantidades, contra o mais barato depois deste', () {
    final review = TripReview.of(
      entries: const [],
      cart: [_cart('cafe', cents: 1899, quantity: 2), _cart('arroz', cents: 2790)],
      marketId: 'vila',
      prices: {
        'vila': (marketName: 'Vila', byProduct: {'cafe': const Money.cents(1899), 'arroz': const Money.cents(2790)}),
        'centro': (
          marketName: 'Centro',
          byProduct: {'cafe': const Money.cents(2099), 'arroz': const Money.cents(2890)},
        ),
        'bairro': (
          marketName: 'Bairro',
          byProduct: {'cafe': const Money.cents(2199), 'arroz': const Money.cents(2990)},
        ),
        // Sem preço do arroz: não entra na comparação.
        'longe': (marketName: 'Longe', byProduct: {'cafe': const Money.cents(999)}),
      },
    );

    // Centro: 2 × 20,99 + 28,90 = 70,88; aqui: 2 × 18,99 + 27,90 = 65,88.
    expect(review.savings, (marketName: 'Centro', amount: const Money.cents(500)));
  });

  test('sem economia quando outro mercado sai mais barato ou falta preço aqui', () {
    TripReview reviewAt(Map<String, Money> here) => TripReview.of(
      entries: const [],
      cart: [_cart('cafe', cents: 1899)],
      marketId: 'vila',
      prices: {
        'vila': (marketName: 'Vila', byProduct: here),
        'centro': (marketName: 'Centro', byProduct: {'cafe': const Money.cents(1799)}),
      },
    );

    expect(reviewAt({'cafe': const Money.cents(1899)}).savings, isNull);
    expect(reviewAt(const {}).savings, isNull);
  });

  test('o que o carrinho não alcançou da lista falta com a diferença', () {
    final review = TripReview.of(
      entries: [_listed('leite', quantity: 3), _listed('cafe', quantity: 2), _listed('arroz', quantity: 2)],
      cart: [_cart('leite'), _cart('cafe', quantity: 2), _cart('arroz', quantity: 2, take: false)],
    );

    // O arroz sem "levar" não conta: faltam os dois.
    expect(review.missing, [(name: 'leite', quantity: 2), (name: 'arroz', quantity: 2)]);
  });

  test('o marcado à mão entra no total pelo preço esperado, ou como sem preço', () {
    final review = TripReview.of(
      entries: [_listed('leite', checked: true, quantity: 2), _listed('ovos', checked: true)],
      cart: [_cart('cafe', cents: 1899)],
      expected: {'leite': const Money.cents(499)},
    );

    expect(review.spent, const Money.cents(1899 + 2 * 499));
    expect(review.estimated, isTrue);
    expect(review.unpriced, 1);
  });
}
