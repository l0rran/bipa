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

  test('congelado vence o ingrediente', () {
    expect(ProductKind.of('Lasanha congelada Sadia'), ProductKind.frozen);
    expect(ProductKind.of('Pão de queijo congelado'), ProductKind.frozen);
    expect(ProductKind.of('Hambúrguer bovino').aisle, Aisle.frozen);
    expect(ProductKind.of('Lasanha à bolonhesa'), ProductKind.pasta);
  });

  test('enlatado e longa vida são de prateleira, na mercearia', () {
    for (final name in [
      'Atum em lata',
      'Sardinha 125 g',
      'Milho verde em lata',
      'Leite longa vida',
      'Leite caixinha',
    ]) {
      expect(ProductKind.of(name), ProductKind.shelfStable, reason: name);
      expect(ProductKind.of(name).aisle, Aisle.grocery, reason: name);
    }
    expect(ProductKind.of('Leite integral 1 L'), ProductKind.dairy);
    expect(ProductKind.of('Cerveja lata 350 ml'), ProductKind.drinks);
  });

  test('"ovomaltine" não é ovo', () {
    expect(ProductKind.of('Ovomaltine'), ProductKind.sweets);
    expect(ProductKind.of('Ovo de codorna'), ProductKind.eggs);
    expect(ProductKind.of('Ovos brancos 12 un'), ProductKind.eggs);
  });
}
