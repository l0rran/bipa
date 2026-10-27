import 'package:flutter/material.dart';

/// Ícone da categoria de um produto, deduzido do nome. É o plano B quando o
/// produto não tem foto: um desenho da categoria em quadro neutro, nunca uma
/// imagem genérica que pareça a foto real.
IconData productCategoryIcon(String name) {
  // Espaços nas pontas: a palavra-chave precisa começar no início de uma
  // palavra ("ovo" casa com "ovos", "cha" não casa com "salsicha"), e uma
  // palavra-chave terminada em espaço só casa com a palavra inteira ("sal ").
  final padded = ' ${_withoutAccents(name.toLowerCase())} ';
  for (final (keywords, icon) in _categories) {
    if (keywords.any((keyword) => padded.contains(' $keyword'))) return icon;
  }
  return Icons.inventory_2_outlined;
}

// A ordem importa: categorias mais específicas vêm antes ("leite condensado"
// é mercearia doce, não laticínio; "água sanitária" é limpeza, não bebida).
const _categories = <(List<String>, IconData)>[
  (['leite condensado', 'creme de leite', 'doce de leite', 'chocolate', 'biscoito', 'bolacha'], Icons.cookie_outlined),
  (['cafe'], Icons.coffee_outlined),
  (['cha ', 'erva mate'], Icons.emoji_food_beverage_outlined),
  (['leite', 'iogurte', 'queijo', 'manteiga', 'requeijao', 'margarina'], Icons.local_drink_outlined),
  (['ovo'], Icons.egg_outlined),
  (['pao', 'torrada', 'bisnaguinha'], Icons.bakery_dining_outlined),
  (['arroz', 'feijao', 'lentilha', 'grao', 'milho', 'aveia'], Icons.rice_bowl_outlined),
  (['macarrao', 'massa', 'espaguete', 'lasanha'], Icons.ramen_dining_outlined),
  (['farinha', 'acucar', 'sal ', 'fuba'], Icons.grain),
  (['oleo', 'azeite', 'vinagre'], Icons.water_drop_outlined),
  (['carne', 'frango', 'linguica', 'salsicha', 'bacon', 'presunto'], Icons.kebab_dining_outlined),
  (['peixe', 'atum', 'sardinha'], Icons.set_meal_outlined),
  (['banana', 'maca', 'laranja', 'tomate', 'batata', 'cebola', 'alface', 'fruta', 'legume'], Icons.eco_outlined),
  (['sorvete'], Icons.icecream_outlined),
  (['sabao', 'amaciante', 'lava roupa'], Icons.local_laundry_service_outlined),
  (['detergente', 'desinfetante', 'agua sanitaria', 'limpador', 'esponja'], Icons.cleaning_services_outlined),
  (['papel higienico', 'sabonete', 'shampoo', 'creme dental', 'pasta de dente', 'desodorante'], Icons.sanitizer_outlined),
  (['racao'], Icons.pets_outlined),
  (['cerveja', 'vinho', 'refrigerante', 'suco', 'agua mineral', 'agua com gas', 'agua sem gas'], Icons.local_bar_outlined),
];

String _withoutAccents(String text) {
  const from = 'áàâãäéèêëíìîïóòôõöúùûüç';
  const to = 'aaaaaeeeeiiiiooooouuuuc';
  final buffer = StringBuffer();
  for (final char in text.split('')) {
    final index = from.indexOf(char);
    buffer.write(index >= 0 ? to[index] : char);
  }
  return buffer.toString();
}
