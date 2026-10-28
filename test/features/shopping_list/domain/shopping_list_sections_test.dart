import 'package:bipa/core/catalog/product_kind.dart';
import 'package:bipa/core/money/money.dart';
import 'package:bipa/features/shopping_list/domain/shopping_list_item.dart';
import 'package:bipa/features/shopping_list/domain/shopping_list_sections.dart';
import 'package:flutter_test/flutter_test.dart';

final _start = DateTime(2026, 10, 28, 9);

ShoppingListEntry entry(String name, {int minute = 0, int? checkedMinute, String? productId}) => ShoppingListEntry(
  item: ShoppingListItem(
    id: name,
    productId: productId,
    name: name,
    addedAt: _start.add(Duration(minutes: minute)),
    checkedAt: checkedMinute == null ? null : _start.add(Duration(minutes: checkedMinute)),
  ),
);

void main() {
  test('agrupa pelas seções do mercado, na ordem do percurso', () {
    final sections = shoppingListSections([
      entry('Café Pilão 500 g'),
      entry('Detergente Ypê'),
      entry('Tomate italiano'),
      entry('Arroz 5 kg'),
    ]);

    expect(sections.map((s) => s.aisle), [Aisle.produce, Aisle.grocery, Aisle.cleaning]);
    expect(sections[1].entries.map((e) => e.name), ['Café Pilão 500 g', 'Arroz 5 kg']);
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

  test('sem preço conhecido, não há estimativa', () {
    final summary = ShoppingListSummary.of([entry('Pão')], const {});

    expect(summary.estimate, isNull);
    expect(ShoppingListSummary.of(const [], const {}).isEmpty, isTrue);
  });
}
