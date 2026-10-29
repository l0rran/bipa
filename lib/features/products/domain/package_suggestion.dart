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
  /// como produto novo, com o acento das palavras comuns ("Feijão"). Tamanho e unidade vêm do fim do nome ("5KG"); a marca
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
      newProductName: match == null ? _capitalize(_accentWord(words.first)) : null,
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
const _connectors = {'de', 'da', 'do', 'das', 'dos', 'com', 'sem', 'e', 'em', 'a'};

/// Palavras da embalagem, não do produto: ruído para quem procura.
const _packaging = {
  'tipo',
  'tp',
  'pct',
  'pacote',
  'cx',
  'caixa',
  'lata',
  'garrafa',
  'bdj',
  'bandeja',
  'pote',
  'frasco',
  'sache',
  'saco',
  'emb',
  'embalagem',
  'granel',
};

/// Unidades soltas, sem número ("BANANA PRATA KG"): é o "por quilo" da
/// etiqueta, não parte do nome.
const _units = {
  'kg',
  'kgs',
  'g',
  'gr',
  'grs',
  'ml',
  'l',
  'lt',
  'lts',
  'litro',
  'litros',
  'un',
  'und',
  'unid',
  'unidade',
  'unidades',
};

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
const _descriptors = {..._connectors, ..._packaging, ..._units, ..._traits};

/// Marcas comuns no mercado, sem acento e em minúsculas. O recorte da
/// etiqueta só tira uma palavra como marca se ela estiver aqui: uma marca
/// que fica no nome custa menos que uma variedade que some (G6). Ficam de
/// fora as marcas que também são palavras de produto ("prato", "galo").
const _knownBrands = {
  'adria',
  'aurora',
  'barilla',
  'batavo',
  'bauducco',
  'camil',
  'catupiry',
  'coqueiro',
  'danone',
  'dona benta',
  'elege',
  'fugini',
  'friboi',
  'gomes da costa',
  'heinz',
  'hellmanns',
  'italac',
  'itambe',
  'kicaldo',
  'knorr',
  'liza',
  'maggi',
  'marilan',
  'melitta',
  'moca',
  'nescau',
  'nestle',
  'ninho',
  'omo',
  'parmalat',
  'perdigao',
  'pilao',
  'piracanjuba',
  'piraque',
  'polenghi',
  'pomarola',
  'qualy',
  'renata',
  'sadia',
  'santa clara',
  'seara',
  'soya',
  'swift',
  'tio joao',
  'tres coracoes',
  'uniao',
  'vitarella',
  'yoki',
  'ype',
};

final _knownBrandWords = [for (final brand in _knownBrands) brand.split(' ')];

/// O acento das palavras de mercado mais comuns, que a etiqueta escreve sem
/// ("FEIJAO"), para o nome do produto novo não nascer "Feijao" (G6). Só
/// palavras sem outra leitura no mercado: uma palavra fora daqui fica como
/// veio, sem acento inventado.
const _accents = {
  'acai': 'açaí',
  'acem': 'acém',
  'acucar': 'açúcar',
  'agua': 'água',
  'alcool': 'álcool',
  'brocolis': 'brócolis',
  'cafe': 'café',
  'camarao': 'camarão',
  'cha': 'chá',
  'coxao': 'coxão',
  'feijao': 'feijão',
  'figado': 'fígado',
  'file': 'filé',
  'fuba': 'fubá',
  'graos': 'grãos',
  'hamburguer': 'hambúrguer',
  'higienico': 'higiênico',
  'limao': 'limão',
  'maca': 'maçã',
  'macarrao': 'macarrão',
  'mamao': 'mamão',
  'maracuja': 'maracujá',
  'melao': 'melão',
  'moida': 'moída',
  'moido': 'moído',
  'musculo': 'músculo',
  'oleo': 'óleo',
  'pao': 'pão',
  'pessego': 'pêssego',
  'pimentao': 'pimentão',
  'po': 'pó',
  'pure': 'purê',
  'requeijao': 'requeijão',
  'sabao': 'sabão',
};

/// [word], sem acento e em minúsculas, com o acento de [_accents].
String _accentWord(String word) => _accents[word] ?? word;

typedef _Token = ({String word, String text});

/// As palavras da etiqueta: `word` sem acento e em minúsculas, para
/// comparar, e `text` como foi lida, para guardar o acento que a etiqueta
/// tiver ("FEIJÃO").
List<_Token> _tokens(String hint) {
  final folded = foldText(hint);
  // O fold troca letra por letra: com o mesmo tamanho, cada palavra tem o
  // trecho original no mesmo lugar.
  final sameLength = folded.length == hint.length;
  return [
    for (final match in _wordPattern.allMatches(folded))
      (word: match.group(0)!, text: sameLength ? hint.substring(match.start, match.end) : match.group(0)!),
  ];
}

/// As posições das palavras que formam uma marca de [_knownBrands], que
/// pode ter mais de uma palavra ("tio joao").
Set<int> _brandPositions(List<String> words) {
  final found = <int>{};
  for (var i = 0; i < words.length; i++) {
    for (final brand in _knownBrandWords) {
      if (i + brand.length > words.length) continue;
      var same = true;
      for (var j = 0; j < brand.length && same; j++) {
        same = words[i + j] == brand[j];
      }
      if (same) found.addAll([for (var j = i; j < i + brand.length; j++) j]);
    }
  }
  return found;
}

/// O nome de produto que a etiqueta sugere (G6): todas as palavras dela,
/// tirando só o que com certeza não distingue o produto, que é número,
/// tamanho, unidade, palavra da embalagem e marca de [_knownBrands]. A
/// variedade fica: "BANANA PRATA KG" é "Banana prata", e "QUEIJO MINAS
/// FRESCAL KG", "Queijo minas frescal". Uma palavra desconhecida também
/// fica, porque um nome um pouco mais longo é melhor que dois produtos
/// fundidos num só, com os preços misturados.
///
/// Sai em minúsculas com a primeira maiúscula e com o acento das palavras
/// comuns ("FEIJAO CARIOCA CAMIL 1KG" é "Feijão carioca"); o acento que a
/// etiqueta tiver fica. Uma palavra que liga outras ("de", "em") só fica
/// entre duas que ficam ("Sabão em pó"). Se só sobra a marca ("NESCAU
/// 400G"), ela é o nome.
String productNameFromLabel(String? nameHint) {
  final hint = nameHint?.trim() ?? '';
  if (hint.isEmpty) return '';
  final tokens = _tokens(hint);
  final words = [for (final token in tokens) token.word];
  final (_, _, sizeWords) = _size(foldText(hint));
  final brands = _brandPositions(words);

  bool content(int i) {
    final word = words[i];
    final noise =
        _isNumber(word) ||
        sizeWords.contains(word) ||
        _units.contains(word) ||
        _packaging.contains(word) ||
        _connectors.contains(word);
    return !noise;
  }

  var kept = [for (var i = 0; i < words.length; i++) content(i) && !brands.contains(i)];
  if (!kept.contains(true)) kept = [for (var i = 0; i < words.length; i++) content(i)];

  final name = <String>[];
  for (var i = 0; i < tokens.length; i++) {
    final connectsKept = _connectors.contains(words[i]) && name.isNotEmpty && i + 1 < tokens.length && kept[i + 1];
    if (!kept[i] && !connectsKept) continue;
    final token = tokens[i];
    final hasAccent = token.text.toLowerCase() != token.word;
    name.add(hasAccent ? token.text : _accentWord(token.word));
  }
  if (name.isEmpty) return '';
  final text = name.join(' ').toLowerCase();
  return text[0].toUpperCase() + text.substring(1);
}

/// O texto com que a escolha de produto abre a partir do nome lido numa
/// etiqueta (G4). A etiqueta vem crua ("FEIJAO CARIOCA CAMIL 1KG"), e a busca
/// pede todas as palavras: com a marca e o tamanho, ela não acharia o
/// "Feijão carioca" cadastrado.
///
/// 1. Um produto cujo nome inteiro está na etiqueta (o mesmo critério de
///    [PackageSuggestion.from]): abre com o nome dele, que a busca acha. Se
///    a etiqueta tem palavras que ele não tem ("BANANA NANICA KG" e o
///    produto "Banana"), a escolha oferece também cadastrar o recorte
///    ([productNameFromLabel]), para a variedade nova não cair nele (G6).
/// 2. Senão, o recorte da etiqueta ([productNameFromLabel]), que é também o
///    nome de um produto novo, se a pessoa cadastrar.
/// 3. Se nenhum produto tem todas as palavras do recorte, e um só tem a
///    maioria delas, abre com o nome dele: em "ACHOC PO MALTADO 400G", o
///    nome vem abreviado, e "achoc" e "po" acham o "Achocolatado em pó".
///    Isso só vale para o texto inicial: a busca continua pedindo todas as
///    palavras, e com um empate não adivinha (passo 4).
/// 4. Se ainda assim nada acha, abre com uma só palavra do recorte que ache
///    algum produto ([_shorterQuery], G9): a etiqueta tem uma palavra a mais
///    ("LIMAO TAITI" e o "Limão tahiti") e a lista vazia esconderia o que a
///    pessoa já tem. O "Criar" segue com o recorte inteiro.
String productQueryFromLabel(String? nameHint, {required List<Product> products}) {
  final hint = nameHint?.trim() ?? '';
  if (hint.isEmpty) return '';
  if (PackageSuggestion.from(hint, products: products).product case final match?) return match.name;

  final query = productNameFromLabel(hint);
  if (query.isEmpty) return '';
  if (products.any((product) => matchesProductSearch(query, name: product.name))) return query;

  final words = {
    for (final word in searchWords(query))
      // Uma letra solta ("o", "c") está em quase todo nome: não conta.
      if (word.length > 1 && !_connectors.contains(word)) word,
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
  if (best != null && !tied && bestCount * 2 > words.length) return best.name;
  return _shorterQuery(query, products: products) ?? query;
}

/// Uma palavra do recorte [query] que ainda acha produto, para a escolha não
/// abrir vazia só porque a etiqueta tem uma palavra que o cadastro não tem
/// (G9): "LIMAO TAITI KG" e o "Limão tahiti", ou "MUSSARELA TIROLEZ KG" e o
/// "Queijo mussarela". Fica a palavra que acha menos produtos (a mais
/// específica); com empate, a primeira. O nome a criar continua sendo o
/// recorte inteiro, que a escolha mantém à parte. Sem palavra que ache, ou
/// com uma só palavra, devolve `null`.
String? _shorterQuery(String query, {required List<Product> products}) {
  final candidates = query.split(' ').where((word) => word.length > 2 && !_connectors.contains(foldText(word)));
  String? best;
  var bestCount = 0;
  for (final word in candidates) {
    final count = products.where((product) => matchesProductSearch(word, name: product.name)).length;
    if (count > 0 && (best == null || count < bestCount)) (best, bestCount) = (word, count);
  }
  if (best == null || best == query) return null;
  return best[0].toUpperCase() + best.substring(1);
}
