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
const _coffeeCode = '7891000100103';

/// Item bipado há [secondsAgo] segundos; a embalagem tem o id do produto com
/// o sufixo `-pkg`.
CartEntry _inCart(String id, {required int secondsAgo}) => CartEntry(
  item: CartItem(
    id: 'item-$id',
    tripId: 't',
    productId: id,
    packageId: '$id-pkg',
    addedAt: _now.subtract(Duration(seconds: secondsAgo)),
  ),
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

    expect(_router.route(_read, cart: cart, now: _now), WaitForProduct(PendingTagPrice(read: _read, readAt: _now)));
  });

  test('a etiqueta do lado não sobrescreve um preço já firmado', () {
    final cart = [_inCart('rice', secondsAgo: 5)];

    final destination = _router.route(_read, cart: cart, now: _now, settled: {'item-rice'});

    expect(destination, isA<WaitForProduct>());
  });

  test('a etiqueta do último item, lida de novo, não espera o próximo produto', () {
    final rice = _inCart('rice', secondsAgo: 40);
    final priced = CartEntry(
      item: CartItem(
        id: rice.item.id,
        tripId: 't',
        productId: 'rice',
        packageId: 'rice-pkg',
        addedAt: rice.item.addedAt,
        price: _read.price,
      ),
      product: rice.product,
    );

    expect(_router.route(_read, cart: [priced], now: _now, settled: {'item-rice'}), SameTagAgain(priced));
    // Outro preço, com o item firmado: é outra etiqueta, que espera o produto.
    const other = TagPriceRead(price: Money.cents(1899));
    expect(_router.route(other, cart: [priced], now: _now, settled: {'item-rice'}), isA<WaitForProduct>());
  });

  test('etiqueta com código: o preço é da embalagem do código, esteja onde estiver no carrinho', () {
    final coffee = _inCart('coffee', secondsAgo: 300);
    final cart = [_inCart('rice', secondsAgo: 2), coffee];
    const read = TagPriceRead(price: Money.cents(1899), barcode: _coffeeCode);

    expect(
      _router.route(read, cart: cart, now: _now, tagPackageId: 'coffee-pkg', settled: {'item-coffee'}),
      PriceCartItem(coffee),
    );
  });

  test('etiqueta com código fora do carrinho, conhecido ou não, espera aquela embalagem', () {
    final cart = [_inCart('rice', secondsAgo: 2)];
    const read = TagPriceRead(price: Money.cents(1899), barcode: _coffeeCode);
    final expected = WaitForProduct(PendingTagPrice(read: read, readAt: _now, barcode: _coffeeCode));

    expect(_router.route(read, cart: cart, now: _now, tagPackageId: 'coffee-pkg'), expected);
    expect(_router.route(read, cart: cart, now: _now), expected);
  });

  test('carrinho vazio: o preço espera', () {
    expect(_router.route(_read, cart: const [], now: _now), isA<WaitForProduct>());
  });

  test('o preço que espera vale para o próximo produto, por pouco tempo', () {
    final pending = PendingTagPrice(read: _read, readAt: _now);
    final later = _now.add(const Duration(seconds: 10));
    final tooLate = _now.add(const Duration(seconds: 30));

    expect(_router.fits(pending, barcode: _riceCode, now: later), isTrue);
    expect(_router.fits(pending, barcode: _riceCode, now: tooLate), isFalse);
  });

  test('o preço de uma etiqueta com código só vale para a embalagem com esse código', () {
    final byCode = PendingTagPrice(read: _read, readAt: _now, barcode: _riceCode);

    expect(_router.fits(byCode, barcode: _riceCode, now: _now), isTrue);
    expect(_router.fits(byCode, barcode: _coffeeCode, now: _now), isFalse);
  });

  test('uma etiqueta sem código com nome não vale para um produto de outra seção', () {
    final pending = PendingTagPrice(
      read: const TagPriceRead(price: Money.cents(2790), nameHint: 'ARROZ BRANCO TIO JOAO 5KG'),
      readAt: _now,
    );

    expect(_router.fits(pending, barcode: _riceCode, now: _now, productName: 'Arroz branco'), isTrue);
    expect(_router.fits(pending, barcode: _coffeeCode, now: _now, productName: 'Detergente Ypê'), isFalse);
    // Sem seção conhecida de um dos lados, não há como dizer que não bate.
    expect(_router.fits(pending, barcode: _coffeeCode, now: _now, productName: 'Coisa'), isTrue);
  });
}
