import 'package:bipa/core/catalog/product_kind.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cada tipo fica na sua seção do mercado', () {
    expect(ProductKind.of('Tomate italiano').aisle, Aisle.produce);
    expect(ProductKind.of('Café Pilão 500 g').aisle, Aisle.grocery);
    expect(ProductKind.of('Ovos brancos 12 un').aisle, Aisle.dairy);
    expect(ProductKind.of('Leite condensado Moça').aisle, Aisle.sweets);
    expect(ProductKind.of('Água sanitária Qboa').aisle, Aisle.cleaning);
    expect(ProductKind.of('Pilhas AA').aisle, Aisle.other);
  });

  test('palavra-chave só casa no começo de uma palavra', () {
    expect(ProductKind.of('Salsicha Sadia'), ProductKind.meat);
    expect(ProductKind.of('Sal refinado'), ProductKind.baking);
  });
}
