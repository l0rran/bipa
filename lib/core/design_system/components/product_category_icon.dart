import 'package:bipa/core/catalog/product_kind.dart';
import 'package:flutter/material.dart';

/// Ícone da categoria de um produto, deduzido do nome. É o plano B quando o
/// produto não tem foto: um desenho da categoria em quadro neutro, nunca uma
/// imagem genérica que pareça a foto real.
IconData productCategoryIcon(String name) => ProductKind.of(name).icon;

extension ProductKindIcon on ProductKind {
  IconData get icon => switch (this) {
    ProductKind.sweets => Icons.cookie_outlined,
    ProductKind.coffee => Icons.coffee_outlined,
    ProductKind.tea => Icons.emoji_food_beverage_outlined,
    ProductKind.dairy => Icons.local_drink_outlined,
    ProductKind.eggs => Icons.egg_outlined,
    ProductKind.bakery => Icons.bakery_dining_outlined,
    ProductKind.grains => Icons.rice_bowl_outlined,
    ProductKind.pasta => Icons.ramen_dining_outlined,
    ProductKind.baking => Icons.grain,
    ProductKind.oils => Icons.water_drop_outlined,
    ProductKind.meat => Icons.kebab_dining_outlined,
    ProductKind.fish => Icons.set_meal_outlined,
    ProductKind.shelfStable => Icons.shelves,
    ProductKind.produce => Icons.eco_outlined,
    ProductKind.frozen => Icons.icecream_outlined,
    ProductKind.laundry => Icons.local_laundry_service_outlined,
    ProductKind.cleaning => Icons.cleaning_services_outlined,
    ProductKind.hygiene => Icons.sanitizer_outlined,
    ProductKind.pet => Icons.pets_outlined,
    ProductKind.drinks => Icons.local_bar_outlined,
    ProductKind.other => Icons.inventory_2_outlined,
  };
}
