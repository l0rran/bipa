import 'package:meta/meta.dart';

/// O que a pessoa escreveu no campo da lista, separado em nome e quantidade:
/// "2 leite", "2x leite", "leite 2" e "leite x2" viram 2 de "leite".
///
/// Só um número inteiro solto, de 1 a 99, no começo ou no fim conta como
/// quantidade. O número colado a uma unidade ("coca 2l") ou no meio do nome
/// ("pão 7 grãos") continua no nome.
@immutable
final class ListEntryText {
  const ListEntryText(this.name, {this.quantity});

  factory ListEntryText.parse(String text) {
    final trimmed = text.trim();
    for (final (pattern, nameGroup, quantityGroup) in _patterns) {
      final match = pattern.firstMatch(trimmed);
      if (match == null) continue;
      final quantity = int.parse(match.group(quantityGroup)!);
      final name = match.group(nameGroup)!.trim();
      if (quantity > 0 && name.isNotEmpty) return ListEntryText(name, quantity: quantity);
    }
    return ListEntryText(trimmed);
  }

  /// "2 leite", "2x leite", "2 x leite", "2× leite".
  static final _leading = RegExp(r'^(\d{1,2})(?:\s*[x×])?\s+(\S.*)$', caseSensitive: false);

  /// "leite 2", "leite x2", "leite x 2", "leite 2x".
  static final _trailing = RegExp(r'^(.*?\S)\s+(?:[x×]\s*)?(\d{1,2})(?:\s*[x×])?$', caseSensitive: false);

  static final _patterns = [(_leading, 2, 1), (_trailing, 1, 2)];

  final String name;

  /// A quantidade escrita; `null` quando não há número.
  final int? quantity;

  @override
  bool operator ==(Object other) => other is ListEntryText && other.name == name && other.quantity == quantity;

  @override
  int get hashCode => Object.hash(name, quantity);

  @override
  String toString() => 'ListEntryText(${quantity ?? '-'}× $name)';
}
