import 'package:bipa/core/money/money.dart';
import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/shopping_list/domain/cart_item.dart';
import 'package:bipa/features/shopping_list/domain/live_scan.dart';
import 'package:bipa/features/shopping_list/domain/live_tag_router.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 10, 28, 9, 30);
const _read = TagPriceRead(price: Money.cents(2790));
const _router = LiveTagRouter();
const _riceCode = '7891910000197';

/// Item bipado há [secondsAgo] segundos.
CartEntry _inCart(String id, {required int secondsAgo}) => CartEntry(
  item: CartItem(id: 'item-$id', tripId: 't', productId: id, addedAt: _now.subtract(Duration(seconds: secondsAgo))),
  product: Product(id: id, name: id, unit: MeasureUnit.unit, createdAt: _now, updatedAt: _now),
);

void main() {
  test('o preço vai para o último item, se ele acabou de ser bipado', () {
    final rice = _inCart('rice', secondsAgo: 5);
    final cart = [rice, _inCart('coffee', secondsAgo: 60)];

    expect(_router.route(_read, cart: cart, now: _now), PriceCartItem(rice));
  });

  test('item bipado há muito tempo não recebe o preço: ele espera o próximo produto', () {
    final cart = [_inCart('rice', secondsAgo: 45)];

    expect(
      _router.route(_read, cart: cart, now: _now),
      WaitForProduct(PendingTagPrice(read: _read, readAt: _now)),
    );
  });

  test('a etiqueta do lado não sobrescreve um preço já firmado', () {
    final cart = [_inCart('rice', secondsAgo: 5)];

    final destination = _router.route(_read, cart: cart, now: _now, settled: {'item-rice'});

    expect(destination, isA<WaitForProduct>());
  });

  test('etiqueta com código: o preço é do produto do código, esteja onde estiver no carrinho', () {
    final coffee = _inCart('coffee', secondsAgo: 300);
    final cart = [_inCart('rice', secondsAgo: 2), coffee];
    const read = TagPriceRead(price: Money.cents(1899), barcode: '7891000100103');

    expect(
      _router.route(read, cart: cart, now: _now, tagProductId: 'coffee', settled: {'item-coffee'}),
      PriceCartItem(coffee),
    );
    expect(
      _router.route(read, cart: cart, now: _now, tagProductId: 'milk'),
      WaitForProduct(PendingTagPrice(read: read, readAt: _now, productId: 'milk')),
    );
  });

  test('etiqueta com um código que nenhum produto tem não vai para o último item', () {
    final cart = [_inCart('coffee', secondsAgo: 2)];
    const read = TagPriceRead(price: Money.cents(2790), barcode: _riceCode);

    expect(
      _router.route(read, cart: cart, now: _now),
      WaitForProduct(PendingTagPrice(read: read, readAt: _now, barcode: _riceCode)),
    );
  });

  test('carrinho vazio: o preço espera', () {
    expect(_router.route(_read, cart: const [], now: _now), isA<WaitForProduct>());
  });

  test('o preço que espera vale para o próximo produto, por pouco tempo', () {
    final pending = PendingTagPrice(read: _read, readAt: _now);
    final later = _now.add(const Duration(seconds: 10));
    final tooLate = _now.add(const Duration(seconds: 30));

    expect(_router.fits(pending, productId: 'rice', barcode: _riceCode, now: later), isTrue);
    expect(_router.fits(pending, productId: 'rice', barcode: _riceCode, now: tooLate), isFalse);
  });

  test('o preço de uma etiqueta com código só vale para aquele produto', () {
    final byProduct = PendingTagPrice(read: _read, readAt: _now, productId: 'milk');
    final byCode = PendingTagPrice(read: _read, readAt: _now, barcode: _riceCode);

    expect(_router.fits(byProduct, productId: 'milk', barcode: '7891000100103', now: _now), isTrue);
    expect(_router.fits(byProduct, productId: 'rice', barcode: _riceCode, now: _now), isFalse);
    expect(_router.fits(byCode, productId: 'rice', barcode: _riceCode, now: _now), isTrue);
    expect(_router.fits(byCode, productId: 'coffee', barcode: '7891000100103', now: _now), isFalse);
  });

  test('o nome da etiqueta que espera vale para cadastrar um produto novo com o mesmo código, ou sem código', () {
    final byCode = PendingTagPrice(read: _read, readAt: _now, barcode: _riceCode);
    final noCode = PendingTagPrice(read: _read, readAt: _now);
    final byProduct = PendingTagPrice(read: _read, readAt: _now, productId: 'milk');
    final tooLate = _now.add(const Duration(seconds: 30));

    expect(_router.fitsUnknownProduct(byCode, barcode: _riceCode, now: _now), isTrue);
    expect(_router.fitsUnknownProduct(byCode, barcode: '7891000100103', now: _now), isFalse);
    expect(_router.fitsUnknownProduct(noCode, barcode: _riceCode, now: _now), isTrue);
    expect(_router.fitsUnknownProduct(noCode, barcode: _riceCode, now: tooLate), isFalse);
    expect(_router.fitsUnknownProduct(byProduct, barcode: _riceCode, now: _now), isFalse);
  });
}
