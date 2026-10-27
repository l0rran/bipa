import 'package:bipa/core/design_system/components/product_category_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('deduz a categoria pelo nome, sem acento e sem diferenciar maiúsculas', () {
    expect(productCategoryIcon('Leite integral 1 L'), Icons.local_drink_outlined);
    expect(productCategoryIcon('CAFÉ Pilão 500 g'), Icons.coffee_outlined);
    expect(productCategoryIcon('Arroz Tio João 5 kg'), Icons.rice_bowl_outlined);
    expect(productCategoryIcon('Ovos brancos 12 un'), Icons.egg_outlined);
  });

  test('categorias específicas vencem as gerais', () {
    expect(productCategoryIcon('Leite condensado Moça'), Icons.cookie_outlined);
    expect(productCategoryIcon('Água sanitária Qboa'), Icons.cleaning_services_outlined);
  });

  test('palavra-chave só casa no começo de uma palavra', () {
    expect(productCategoryIcon('Salsicha Sadia'), Icons.kebab_dining_outlined);
    expect(productCategoryIcon('Sal refinado'), Icons.grain);
    expect(productCategoryIcon('Tomate italiano'), Icons.eco_outlined);
  });

  test('sem categoria conhecida, usa o ícone genérico de produto', () {
    expect(productCategoryIcon('Pilhas AA'), Icons.inventory_2_outlined);
  });
}
