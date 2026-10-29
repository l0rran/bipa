import 'package:bipa/core/catalog/text_fold.dart';

final _separators = RegExp(r'[\s,;:.!?/\\-]+');

/// As palavras de uma busca, sem acento nem maiúsculas ("Feijão  Carioca"
/// vira `[feijao, carioca]`). Espaço e pontuação separam.
List<String> searchWords(String text) => [
  for (final word in foldText(text).split(_separators))
    if (word.isNotEmpty) word,
];

/// Se um produto responde à [query]: todas as palavras dela aparecem, em
/// qualquer ordem, no [name] ou nas [brands] das suas embalagens, sem ligar
/// para acento nem caixa ("acucar" acha "Açúcar"; "carioca feijao" acha
/// "Feijão carioca"). Cada palavra pode estar no meio de uma palavra do nome
/// ("arr" acha "Arroz"). Uma busca igual a um dos [barcodes] também casa.
///
/// O `LIKE` do SQLite só ignora a caixa de letras ASCII e não conhece
/// acento, por isso o filtro é em Dart. O catálogo pessoal tem centenas de
/// produtos, não milhões: percorrer todos a cada mudança custa microssegundos
/// e a lista inteira já é carregada para ordenar sem ligar para o acento.
/// Passando de alguns milhares de produtos, vale uma coluna com o nome já
/// normalizado.
bool matchesProductSearch(
  String query, {
  required String name,
  Iterable<String> brands = const [],
  Iterable<String> barcodes = const [],
}) {
  final words = searchWords(query);
  if (words.isEmpty) return true;
  final term = query.trim();
  if (barcodes.any((barcode) => barcode == term)) return true;
  // O \n separa os campos: uma palavra da busca não atravessa a divisa.
  final haystack = foldText([name, ...brands].join('\n'));
  return words.every(haystack.contains);
}

/// Se [a] e [b] têm as mesmas palavras, na ordem que for e sem acento:
/// "FEIJAO CARIOCA" e "Carioca, feijão" são o mesmo produto para quem busca.
bool sameSearchWords(String a, String b) {
  final first = searchWords(a).toSet();
  final second = searchWords(b).toSet();
  return first.isNotEmpty && first.length == second.length && first.containsAll(second);
}
