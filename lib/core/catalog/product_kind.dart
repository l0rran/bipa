/// Seções do mercado, na ordem em que costumam aparecer num percurso: a lista
/// de compras agrupa os itens por elas.
///
/// É uma ordem genérica. A ordem real dos corredores de cada mercado será
/// aprendida a partir do que a pessoa bipa (roadmap da fase 1).
enum Aisle { produce, bakery, meat, dairy, grocery, sweets, frozen, drinks, cleaning, hygiene, pet, other }

/// Tipo de produto, deduzido do nome. Dá o ícone do produto sem foto e a
/// seção do mercado em que ele fica.
enum ProductKind {
  sweets(Aisle.sweets),
  coffee(Aisle.grocery),
  tea(Aisle.grocery),
  dairy(Aisle.dairy),
  eggs(Aisle.dairy),
  bakery(Aisle.bakery),
  grains(Aisle.grocery),
  pasta(Aisle.grocery),
  baking(Aisle.grocery),
  oils(Aisle.grocery),
  meat(Aisle.meat),
  fish(Aisle.meat),
  produce(Aisle.produce),
  frozen(Aisle.frozen),
  laundry(Aisle.cleaning),
  cleaning(Aisle.cleaning),
  hygiene(Aisle.hygiene),
  pet(Aisle.pet),
  drinks(Aisle.drinks),
  other(Aisle.other);

  const ProductKind(this.aisle);

  final Aisle aisle;

  /// Deduz o tipo pelo nome, sem acento e sem diferenciar maiúsculas.
  static ProductKind of(String name) {
    // Espaços nas pontas: a palavra-chave precisa começar no início de uma
    // palavra ("ovo" casa com "ovos", "cha" não casa com "salsicha"), e uma
    // palavra-chave terminada em espaço só casa com a palavra inteira ("sal ").
    final padded = ' ${_withoutAccents(name.toLowerCase())} ';
    for (final (keywords, kind) in _keywords) {
      if (keywords.any((keyword) => padded.contains(' $keyword'))) return kind;
    }
    return ProductKind.other;
  }
}

// A ordem importa: tipos mais específicos vêm antes ("leite condensado" é doce,
// não laticínio; "água sanitária" é limpeza, não bebida).
const _keywords = <(List<String>, ProductKind)>[
  (['leite condensado', 'creme de leite', 'doce de leite', 'chocolate', 'biscoito', 'bolacha'], ProductKind.sweets),
  (['cafe'], ProductKind.coffee),
  (['cha ', 'erva mate'], ProductKind.tea),
  (['leite', 'iogurte', 'queijo', 'manteiga', 'requeijao', 'margarina'], ProductKind.dairy),
  (['ovo'], ProductKind.eggs),
  (['pao', 'torrada', 'bisnaguinha'], ProductKind.bakery),
  (['arroz', 'feijao', 'lentilha', 'grao', 'milho', 'aveia'], ProductKind.grains),
  (['macarrao', 'massa', 'espaguete', 'lasanha'], ProductKind.pasta),
  (['farinha', 'acucar', 'sal ', 'fuba'], ProductKind.baking),
  (['oleo', 'azeite', 'vinagre'], ProductKind.oils),
  (['carne', 'frango', 'linguica', 'salsicha', 'bacon', 'presunto'], ProductKind.meat),
  (['peixe', 'atum', 'sardinha'], ProductKind.fish),
  (['banana', 'maca', 'laranja', 'tomate', 'batata', 'cebola', 'alface', 'fruta', 'legume'], ProductKind.produce),
  (['sorvete'], ProductKind.frozen),
  (['sabao', 'amaciante', 'lava roupa'], ProductKind.laundry),
  (['detergente', 'desinfetante', 'agua sanitaria', 'limpador', 'esponja'], ProductKind.cleaning),
  (['papel higienico', 'sabonete', 'shampoo', 'creme dental', 'pasta de dente', 'desodorante'], ProductKind.hygiene),
  (['racao'], ProductKind.pet),
  (['cerveja', 'vinho', 'refrigerante', 'suco', 'agua mineral', 'agua com gas', 'agua sem gas'], ProductKind.drinks),
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
