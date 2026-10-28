import 'package:bipa/core/catalog/product_kind.dart';
import 'package:bipa/core/money/money.dart';
import 'package:bipa/features/shopping_list/domain/aisle_order.dart';
import 'package:bipa/features/shopping_list/domain/shopping_list_item.dart';
import 'package:meta/meta.dart';

/// Os itens de uma seção do mercado: o que falta primeiro, na ordem em que
/// entrou, e o que já foi comprado no fim.
@immutable
final class ShoppingListSection {
  const ShoppingListSection({required this.aisle, required this.entries});

  final Aisle aisle;
  final List<ShoppingListEntry> entries;

  int get done => entries.where((e) => e.item.isChecked).length;

  int get total => entries.length;
}

/// Agrupa a lista pelas seções do mercado, na ordem do percurso: a
/// aprendida no mercado da compra ([order], ADR 0014) ou a genérica de
/// [Aisle].
List<ShoppingListSection> shoppingListSections(
  Iterable<ShoppingListEntry> entries, {
  AisleOrder order = AisleOrder.empty,
}) {
  final byAisle = <Aisle, List<ShoppingListEntry>>{};
  for (final entry in entries) {
    byAisle.putIfAbsent(ProductKind.of(entry.name).aisle, () => []).add(entry);
  }
  return [
    for (final aisle in order.sort(byAisle.keys))
      ShoppingListSection(aisle: aisle, entries: _shoppingOrder(byAisle[aisle]!)),
  ];
}

/// A próxima seção do percurso com algo faltando, e o que falta nela (no
/// máximo [maxItems] nomes): é o "Próximo" da notificação da compra.
/// `null` quando tudo da lista já foi pego.
({Aisle aisle, List<String> items})? nextAisle(List<ShoppingListSection> sections, {int maxItems = 3}) {
  for (final section in sections) {
    final missing = [
      for (final entry in section.entries)
        if (!entry.item.isChecked) entry.name,
    ];
    if (missing.isNotEmpty) return (aisle: section.aisle, items: missing.take(maxItems).toList());
  }
  return null;
}

List<ShoppingListEntry> _shoppingOrder(List<ShoppingListEntry> entries) {
  // O id desempata horários iguais: o sort do Dart não é estável.
  int byId(ShoppingListEntry a, ShoppingListEntry b) => a.item.id.compareTo(b.item.id);
  final missing = entries.where((e) => !e.item.isChecked).toList()
    ..sort((a, b) {
      final byTime = a.item.addedAt.compareTo(b.item.addedAt);
      return byTime != 0 ? byTime : byId(a, b);
    });
  final bought = entries.where((e) => e.item.isChecked).toList()
    ..sort((a, b) {
      final byTime = a.item.checkedAt!.compareTo(b.item.checkedAt!);
      return byTime != 0 ? byTime : byId(a, b);
    });
  return [...missing, ...bought];
}

/// Resumo da lista: quanto falta e quanto deve custar.
@immutable
final class ShoppingListSummary {
  const ShoppingListSummary({required this.done, required this.total, this.estimate});

  /// Calcula o resumo com os preços de referência de cada produto.
  ///
  /// A estimativa soma o que ainda falta comprar e só considera os itens com
  /// preço conhecido; sem nenhum, é `null`.
  factory ShoppingListSummary.of(Iterable<ShoppingListEntry> entries, Map<String, Money> prices) {
    var done = 0;
    var total = 0;
    Money? estimate;
    for (final entry in entries) {
      total++;
      if (entry.item.isChecked) {
        done++;
        continue;
      }
      final price = switch (entry.item.productId) {
        final id? => prices[id],
        null => null,
      };
      if (price != null) estimate = (estimate ?? Money.zero) + price * entry.item.quantity;
    }
    return ShoppingListSummary(done: done, total: total, estimate: estimate);
  }

  final int done;
  final int total;
  final Money? estimate;

  int get remaining => total - done;

  bool get isEmpty => total == 0;

  /// Fração comprada, de 0 a 1.
  double get progress => total == 0 ? 0 : done / total;

  @override
  bool operator ==(Object other) =>
      other is ShoppingListSummary && other.done == done && other.total == total && other.estimate == estimate;

  @override
  int get hashCode => Object.hash(done, total, estimate);
}
