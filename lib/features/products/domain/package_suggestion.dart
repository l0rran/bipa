import 'package:bipa/core/catalog/text_fold.dart';
import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/products/domain/product_search.dart';
import 'package:meta/meta.dart';

/// O que o nome lido na etiqueta sugere para uma embalagem nova (ADR 0013):
/// de que produto ela é, a marca e o tamanho. É só uma sugestão: a pessoa
/// confere antes de salvar.
@immutable
final class PackageSuggestion {
  const PackageSuggestion({this.product, this.newProductName, this.brand, this.size, this.unit});

  static const empty = PackageSuggestion();

  /// Um produto que já existe e cujo nome está na etiqueta.
  final Product? product;

  /// Sem [product], o nome sugerido para um produto novo ("Arroz").
  final String? newProductName;
  final String? brand;
  final double? size;
  final MeasureUnit? unit;

  /// A partir de [nameHint] ("ARROZ BRANCO TIO JOAO 5KG"), escolhe entre
  /// [products] o que tem todas as palavras do nome na etiqueta (o mais
  /// específico, se houver mais de um). Sem nenhum, sugere a primeira palavra
  /// como produto novo. Tamanho e unidade vêm do fim do nome ("5KG"); a marca
  /// é o que sobra, tirando o nome do produto e palavras de descrição
  /// ("branco", "tradicional").
  factory PackageSuggestion.from(String? nameHint, {required List<Product> products}) {
    final hint = nameHint?.trim() ?? '';
    if (hint.isEmpty) return empty;
    final folded = foldText(hint);
    final words = _words(folded);
    if (words.isEmpty) return empty;

    final (size, unit, sizeWords) = _size(folded);
    Product? match;
    var matchWords = const <String>{};
    for (final product in products) {
      final productWords = _words(foldText(product.name)).where((w) => !_isNumber(w)).toSet();
      if (productWords.isEmpty || !words.toSet().containsAll(productWords)) continue;
      if (productWords.length > matchWords.length) {
        match = product;
        matchWords = productWords;
      }
    }

    final nameWords = match == null ? {words.first} : matchWords;
    bool isBrand(String word) =>
        !nameWords.contains(word) && !sizeWords.contains(word) && !_isNumber(word) && !_descriptors.contains(word);
    final brandWords = words.where(isBrand).toList();
    return PackageSuggestion(
      product: match,
      newProductName: match == null ? _capitalize(words.first) : null,
      brand: brandWords.isEmpty ? null : brandWords.map(_capitalize).join(' '),
      size: size,
      unit: unit,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PackageSuggestion &&
      other.product == product &&
      other.newProductName == newProductName &&
      other.brand == brand &&
      other.size == size &&
      other.unit == unit;

  @override
  int get hashCode => Object.hash(product, newProductName, brand, size, unit);

  @override
  String toString() => 'PackageSuggestion(${product?.name ?? newProductName}, $brand, $size ${unit?.symbol})';
}

final _wordPattern = RegExp('[a-z0-9]+(?:[.,][0-9]+)?');

List<String> _words(String folded) => [for (final match in _wordPattern.allMatches(folded)) match.group(0)!];

bool _isNumber(String word) => RegExp(r'^[0-9]').hasMatch(word);

/// O último tamanho do nome: "5KG", "500 G", "1,5L", "12 UN". Devolve também
/// as palavras que formavam o tamanho, para tirar da marca.
(double?, MeasureUnit?, Set<String>) _size(String folded) {
  final matches = RegExp(
    r'(\d+(?:[.,]\d+)?)\s?(kg|kgs|g|gr|grs|ml|l|lt|lts|litros?|un|und|unid|unidades?)\b',
  ).allMatches(folded).toList();
  if (matches.isEmpty) return (null, null, const {});
  final last = matches.last;
  final size = double.tryParse(last.group(1)!.replaceAll(',', '.'));
  final unit = switch (last.group(2)!) {
    'kg' || 'kgs' => MeasureUnit.kilogram,
    'g' || 'gr' || 'grs' => MeasureUnit.gram,
    'ml' => MeasureUnit.milliliter,
    'l' || 'lt' || 'lts' || 'litro' || 'litros' => MeasureUnit.liter,
    _ => MeasureUnit.unit,
  };
  return (size, unit, _words(last.group(0)!).toSet());
}

String _capitalize(String word) => word.isEmpty ? word : word[0].toUpperCase() + word.substring(1);

/// Palavras que ligam outras ("sabão em pó"): não são marca nem produto.
const _connectors = {'de', 'da', 'do', 'com', 'sem', 'e', 'em'};

/// Palavras da embalagem, não do produto: ruído para quem procura.
const _packaging = {'tipo', 'tp', 'pct', 'pacote', 'cx', 'caixa', 'lata', 'garrafa'};

/// Palavras que dizem como é o produto ("branco", "carioca"), não a marca.
const _traits = {
  'branco',
  'branca',
  'integral',
  'parboilizado',
  'tradicional',
  'extra',
  'forte',
  'suave',
  'refinado',
  'refinada',
  'cristal',
  'carioca',
  'preto',
  'uht',
  'desnatado',
  'semidesnatado',
  'light',
  'zero',
  'original',
  'classico',
  'especial',
  'premium',
  'novo',
  'nova',
  'po',
  'liquido',
  'graos',
  'moido',
  'torrado',
  'vacuo',
};

/// Palavras que descrevem o produto, não a marca.
const _descriptors = {..._connectors, ..._packaging, ..._traits};

/// O texto com que a escolha de produto abre a partir do nome lido numa
/// etiqueta (G4). A etiqueta vem crua ("FEIJAO CARIOCA CAMIL 1KG"), e a busca
/// pede todas as palavras: com a marca e o tamanho, ela não acharia o
/// "Feijão carioca" cadastrado.
///
/// 1. Um produto cujo nome inteiro está na etiqueta (o mesmo critério de
///    [PackageSuggestion.from]): abre com o nome dele, que a busca acha.
/// 2. Senão, o recorte da etiqueta: a primeira palavra (o produto) e as que
///    dizem como ele é ("carioca", "integral"), sem marca, tamanho, números
///    nem palavras da embalagem, em minúsculas com a primeira maiúscula
///    ("Feijao carioca"). É também o nome de um produto novo, se a pessoa
///    cadastrar.
/// 3. Se nenhum produto tem todas as palavras do recorte, e um só tem a
///    maioria das palavras da etiqueta (sem tamanho nem ruído), abre com o
///    nome dele: em "NESCAU ACHOC PO 400G", a marca vem primeiro e o nome
///    vem abreviado, e "achoc" e "po" acham o "Achocolatado em pó". Isso só
///    vale para o texto inicial: a busca continua pedindo todas as palavras,
///    e com um empate fica o recorte, sem adivinhar.
String productQueryFromLabel(String? nameHint, {required List<Product> products}) {
  final hint = nameHint?.trim() ?? '';
  if (hint.isEmpty) return '';
  if (PackageSuggestion.from(hint, products: products).product case final match?) return match.name;

  final folded = foldText(hint);
  // O fold troca letra por letra: o trecho original de cada palavra guarda o
  // acento, se a etiqueta tiver ("FEIJÃO").
  final sameLength = folded.length == hint.length;
  final tokens = [
    for (final match in _wordPattern.allMatches(folded))
      (word: match.group(0)!, text: sameLength ? hint.substring(match.start, match.end) : match.group(0)!),
  ];
  final (_, _, sizeWords) = _size(folded);
  bool isNoise(String word) =>
      _isNumber(word) || sizeWords.contains(word) || _connectors.contains(word) || _packaging.contains(word);
  final head = tokens.indexWhere((token) => !isNoise(token.word));
  if (head < 0) return '';

  bool kept(int index) => index == head || _traits.contains(tokens[index].word);
  final core = <String>[];
  for (var i = 0; i < tokens.length; i++) {
    final connectsKept =
        _connectors.contains(tokens[i].word) && core.isNotEmpty && i + 1 < tokens.length && kept(i + 1);
    if (kept(i) || connectsKept) core.add(tokens[i].text);
  }
  final text = core.join(' ').toLowerCase();
  final query = text[0].toUpperCase() + text.substring(1);
  if (products.any((product) => matchesProductSearch(query, name: product.name))) return query;

  final words = {
    for (final token in tokens)
      // Uma letra solta ("o", "c") está em quase todo nome: não conta.
      if (!isNoise(token.word) && token.word.length > 1) token.word,
  };
  Product? best;
  var bestCount = 0;
  var tied = false;
  for (final product in products) {
    final name = foldText(product.name);
    final count = words.where(name.contains).length;
    if (count > bestCount) {
      (best, bestCount, tied) = (product, count, false);
    } else if (count == bestCount && count > 0) {
      tied = true;
    }
  }
  return best != null && !tied && bestCount * 2 > words.length ? best.name : query;
}
