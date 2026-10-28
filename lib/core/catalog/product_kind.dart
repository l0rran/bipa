import 'package:bipa/core/catalog/text_fold.dart';

/// Seções do mercado, na ordem em que costumam aparecer num percurso: a lista
/// de compras agrupa os itens por elas.
///
/// É a ordem genérica. A de cada mercado é aprendida com as compras feitas
/// nele (ADR 0014, `AisleOrder`).
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
  shelfStable(Aisle.grocery),
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
    final padded = ' ${foldText(name)} ';
    for (final (keywords, kind) in _keywords) {
      if (keywords.any((keyword) => padded.contains(' $keyword'))) return kind;
    }
    return ProductKind.other;
  }
}

// A ordem importa: tipos mais específicos vêm antes ("leite condensado" é doce,
// não laticínio; "água sanitária" é limpeza, não bebida; "lasanha congelada"
// é congelado, não massa; "leite longa vida" é de prateleira, não laticínio).
const _keywords = <(List<String>, ProductKind)>[
  (
    [
      'leite condensado',
      'creme de leite',
      'doce de leite',
      'chocolate',
      'achocolatado',
      'ovomaltine',
      'nescau',
      'biscoito',
      'bolacha',
    ],
    ProductKind.sweets,
  ),
  (['congelad', 'sorvete', 'hamburguer', 'nuggets'], ProductKind.frozen),
  (['cerveja', 'vinho', 'refrigerante', 'suco', 'agua mineral', 'agua com gas', 'agua sem gas'], ProductKind.drinks),
  (['cafe'], ProductKind.coffee),
  (['cha ', 'erva mate'], ProductKind.tea),
  (
    [
      'longa vida',
      'uht',
      'caixinha',
      'lata',
      'enlatad',
      'conserva',
      'leite em po',
      'leite de coco',
      'atum',
      'sardinha',
    ],
    ProductKind.shelfStable,
  ),
  (['leite', 'iogurte', 'queijo', 'manteiga', 'requeijao', 'margarina'], ProductKind.dairy),
  // "ovo " e "ovos", não "ovo": "ovomaltine" não é ovo.
  (['ovo ', 'ovos'], ProductKind.eggs),
  (['pao', 'torrada', 'bisnaguinha'], ProductKind.bakery),
  (['arroz', 'feijao', 'lentilha', 'grao', 'milho', 'aveia'], ProductKind.grains),
  (['macarrao', 'massa', 'espaguete', 'lasanha'], ProductKind.pasta),
  (['farinha', 'acucar', 'sal ', 'fuba'], ProductKind.baking),
  (['oleo', 'azeite', 'vinagre'], ProductKind.oils),
  (['carne', 'frango', 'linguica', 'salsicha', 'bacon', 'presunto'], ProductKind.meat),
  (['peixe'], ProductKind.fish),
  (['banana', 'maca', 'laranja', 'tomate', 'batata', 'cebola', 'alface', 'fruta', 'legume'], ProductKind.produce),
  (['sabao', 'amaciante', 'lava roupa'], ProductKind.laundry),
  (['detergente', 'desinfetante', 'agua sanitaria', 'limpador', 'esponja'], ProductKind.cleaning),
  (['papel higienico', 'sabonete', 'shampoo', 'creme dental', 'pasta de dente', 'desodorante'], ProductKind.hygiene),
  (['racao'], ProductKind.pet),
];
