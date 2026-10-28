import 'package:bipa/core/catalog/product_kind.dart';
import 'package:bipa/core/money/money.dart';
import 'package:bipa/features/shopping_list/domain/aisle_order.dart';
import 'package:bipa/features/shopping_list/domain/shopping_list_item.dart';
import 'package:bipa/features/shopping_list/domain/shopping_list_sections.dart';
import 'package:flutter_test/flutter_test.dart';

final _start = DateTime(2026, 10, 28, 9);

ShoppingListEntry entry(String name, {int minute = 0, int? checkedMinute, String? productId, int quantity = 1}) =>
    ShoppingListEntry(
      item: ShoppingListItem(
        id: name,
        productId: productId,
        name: name,
        addedAt: _start.add(Duration(minutes: minute)),
        checkedAt: checkedMinute == null ? null : _start.add(Duration(minutes: checkedMinute)),
        quantity: quantity,
      ),
    );

void main() {
  test('agrupa pelas seções do mercado, na ordem do percurso', () {
    final sections = shoppingListSections([
      entry('Café Pilão 500 g'),
      entry('Detergente Ypê', minute: 1),
      entry('Tomate italiano', minute: 2),
      entry('Arroz 5 kg', minute: 3),
    ]);

    expect(sections.map((s) => s.aisle), [Aisle.produce, Aisle.grocery, Aisle.cleaning]);
    expect(sections[1].entries.map((e) => e.name), ['Café Pilão 500 g', 'Arroz 5 kg']);
  });

  test('no mercado da compra, as seções seguem a ordem aprendida nele', () {
    final at = DateTime(2026, 10, 20, 10);
    final order = AisleOrder.empty.learn([
      (aisle: Aisle.cleaning, at: at),
      (aisle: Aisle.grocery, at: at.add(const Duration(minutes: 5))),
      (aisle: Aisle.produce, at: at.add(const Duration(minutes: 10))),
    ]);

    final sections = shoppingListSections([
      entry('Café Pilão 500 g'),
      entry('Detergente Ypê', minute: 1),
      entry('Tomate italiano', minute: 2),
    ], order: order);

    expect(sections.map((s) => s.aisle), [Aisle.cleaning, Aisle.grocery, Aisle.produce]);
  });

  test('em cada seção, o que falta vem antes do que já foi comprado', () {
    final section = shoppingListSections([
      entry('Banana', minute: 1, checkedMinute: 20),
      entry('Tomate', minute: 2),
      entry('Batata', minute: 3, checkedMinute: 10),
      entry('Cebola', minute: 4),
    ]).single;

    expect(section.entries.map((e) => e.name), ['Tomate', 'Cebola', 'Batata', 'Banana']);
    expect((section.done, section.total), (2, 4));
  });

  test('o resumo estima só o que falta e só com preços conhecidos', () {
    final summary = ShoppingListSummary.of(
      [
        entry('Café', productId: 'cafe'),
        entry('Arroz', productId: 'arroz', checkedMinute: 5),
        entry('Pão'),
        entry('Leite', productId: 'leite'),
      ],
      {'cafe': const Money.cents(1899), 'arroz': const Money.cents(2790)},
    );

    expect(summary, const ShoppingListSummary(done: 1, total: 4, estimate: Money.cents(1899)));
    expect(summary.remaining, 3);
    expect(summary.progress, 0.25);
  });

  test('o resumo multiplica o preço pela quantidade da lista', () {
    final summary = ShoppingListSummary.of(
      [entry('Leite', productId: 'leite', quantity: 3)],
      {'leite': const Money.cents(499)},
    );

    expect(summary.estimate, const Money.cents(1497));
  });

  test('sem preço conhecido, não há estimativa', () {
    final summary = ShoppingListSummary.of([entry('Pão')], const {});

    expect(summary.estimate, isNull);
    expect(ShoppingListSummary.of(const [], const {}).isEmpty, isTrue);
  });

  test('o próximo da compra é a primeira seção com algo faltando, com até três nomes', () {
    final sections = shoppingListSections([
      entry('Tomate', checkedMinute: 5),
      entry('Leite integral', minute: 1),
      entry('Ovos', minute: 2),
      entry('Queijo minas', minute: 3),
      entry('Iogurte', minute: 4),
      entry('Arroz 5 kg', minute: 5),
    ]);

    final next = nextAisle(sections);

    expect(next?.aisle, Aisle.dairy);
    expect(next?.items, ['Leite integral', 'Ovos', 'Queijo minas']);
    expect(nextAisle(shoppingListSections([entry('Tomate', checkedMinute: 1)])), isNull);
  });
}
