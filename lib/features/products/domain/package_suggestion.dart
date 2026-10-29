import 'package:bipa/core/catalog/product_kind.dart';
import 'package:bipa/core/catalog/text_fold.dart';
import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:bipa/features/products/domain/package_origin.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/products/domain/product_catalog.dart';
import 'package:bipa/features/products/domain/product_search.dart';
import 'package:meta/meta.dart';

/// O que o nome lido na etiqueta, ou o catálogo pronto, sugere para uma
/// embalagem nova (ADR 0013 e 0024): de que produto ela é, a marca e o
/// tamanho. É só uma sugestão: a pessoa confere antes de salvar.
@immutable
final class PackageSuggestion {
  const PackageSuggestion({
    this.product,
    this.newProductName,
    this.brand,
    this.size,
    this.unit,
    this.origin = PackageOrigin.person,
  });

  static const empty = PackageSuggestion();

  /// Um produto que já existe e cujo nome está na etiqueta.
  final Product? product;

  /// Sem [product], o nome sugerido para um produto novo ("Arroz").
  final String? newProductName;
  final String? brand;
  final double? size;
  final MeasureUnit? unit;

  /// De onde veio a sugestão: da etiqueta (a pessoa) ou do catálogo. A
  /// embalagem salva leva essa origem (ADR 0023, lacuna C1).
  final PackageOrigin origin;

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
    final (match, matchWords) = _productIn(words, products);

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

  /// A embalagem do catálogo pronto (ADR 0024) já traz marca, tamanho e
  /// unidade; falta dizer de que produto da pessoa ela é (ADR 0013).
  ///
  /// O produto é o que começa o nome do catálogo ([_catalogProductIn]):
  /// "Arroz branco" para "Arroz Branco Tipo 1 Tio João", mas não "Leite"
  /// para "Leite Condensado Semidesnatado" (G12). Sem nenhum, sugere um
  /// produto novo com o nome do catálogo sem a marca, o tamanho e as palavras
  /// da embalagem ([_catalogProductName]), e a pessoa ainda pode trocar.
  /// Sem tamanho no catálogo, ele vem da quantidade em texto ("5 kg") ou do
  /// fim do nome.
  factory PackageSuggestion.fromCatalog(CatalogPackage package, {required List<Product> products}) {
    final brand = _catalogBrand(package.brand);
    final newName = _catalogProductName(package.name, brand: brand);
    final match = _catalogProductIn(package, newName: newName, products: products);

    var (size, unit) = (package.size, package.unit);
    if (size == null || unit == null) {
      // Vale o último tamanho do texto: o da quantidade, se houver.
      final (parsedSize, parsedUnit, _) = _size(foldText('${package.name} ${package.quantity ?? ''}'));
      if (parsedSize != null && parsedUnit != null) (size, unit) = (parsedSize, parsedUnit);
    }
    return PackageSuggestion(
      product: match,
      newProductName: match == null ? newName : null,
      brand: brand,
      size: unit == null ? null : size,
      unit: unit,
      origin: package.source,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PackageSuggestion &&
      other.product == product &&
      other.newProductName == newProductName &&
      other.brand == brand &&
      other.size == size &&
      other.unit == unit &&
      other.origin == origin;

  @override
  int get hashCode => Object.hash(product, newProductName, brand, size, unit, origin);

  @override
  String toString() =>
      'PackageSuggestion(${product?.name ?? newProductName}, $brand, $size ${unit?.symbol}, ${origin.name})';
}

/// Entre [products], o que tem todas as palavras do nome em [words], e essas
/// palavras. Vence o mais específico (mais palavras); num empate, o
/// primeiro.
(Product?, Set<String>) _productIn(List<String> words, List<Product> products) {
  final available = words.toSet();
  Product? match;
  var matchWords = const <String>{};
  for (final product in products) {
    final productWords = _words(foldText(product.name)).where((w) => !_isNumber(w)).toSet();
    if (productWords.isEmpty || !available.containsAll(productWords)) continue;
    if (productWords.length > matchWords.length) (match, matchWords) = (product, productWords);
  }
  return (match, matchWords);
}

/// O produto da pessoa para a embalagem do catálogo (G12). O nome do
/// catálogo é longo, e nele cabem produtos genéricos demais: "Leite" está em
/// "Leite Condensado Semidesnatado ITALAC", "Sal" em "Manteiga Sem Sal", e
/// "Uva" em "Fanta Uva". Por isso um produto só é escolhido quando:
///
/// 1. todas as palavras do nome dele estão no nome do catálogo, como na
///    etiqueta ([_productIn]);
/// 2. ele é o começo de [newName], o nome que o catálogo sugere sem marca e
///    tamanho: a primeira palavra que diz o que é ("Uva" em "Uva Thompson",
///    "Leite" em "Leite UHT integral"), e não uma do meio ("Sal" em
///    "Manteiga extra sem sal", "Uva" em "Fanta uva", que leva a marca
///    porque sem ela sobraria só o sabor);
/// 3. o que sobra não tem palavra que muda o tipo ([_typeWords]: sabor,
///    "condensado", "carreteiro", "refrigerante", "suco", "pronto") nem a
///    marca que ficou no nome. Versão e linha não contam: "integral", "em
///    pó", "desnatado", "Lavagem Perfeita", "Cristal";
/// 4. o tipo dele, pelo nome, combina com a categoria do catálogo
///    ([_kindsAgree]): "Laranja" não recebe um refrigerante de laranja.
///
/// Um produto com a marca no nome passa pelos passos 2 e 3: "Coca-cola" fica
/// com "Refrigerante Coca-Cola", e "Nescau" com "Achocolatado Pó Nescau".
/// Entre os que passam, vence o de mais palavras, depois o do tipo da
/// categoria. Na dúvida, nenhum: a folha sugere o produto novo, e a escolha
/// de produto mostra os parecidos a um toque.
Product? _catalogProductIn(CatalogPackage package, {required String newName, required List<Product> products}) {
  final words = _words(foldText(package.name));
  final available = words.toSet();
  final named = _significantWords(_words(foldText(newName)));
  final head = named.isEmpty ? null : named.first;
  final brandWords = {
    for (final brand in package.brand?.split(',') ?? const <String>[]) ..._words(foldText(brand)),
    for (final i in _brandPositions(words)) words[i],
  };

  Product? best;
  var (bestLength, bestKind) = (0, false);
  for (final product in products) {
    final productWords = _words(foldText(product.name)).where((w) => !_isNumber(w)).toSet();
    if (productWords.isEmpty || !available.containsAll(productWords)) continue;
    final productKind = ProductKind.of(product.name);
    if (!_kindsAgree(package.kind, productKind)) continue;

    if (!productWords.any(brandWords.contains)) {
      if (head != null && !productWords.contains(head)) continue;
      final extra = named.where((word) => !productWords.contains(word));
      if (extra.any((word) => _typeWords.contains(word) || brandWords.contains(word))) continue;
    }

    final sameKind = package.kind != null && productKind == package.kind;
    final better =
        best == null ||
        productWords.length > bestLength ||
        (productWords.length == bestLength && sameKind && !bestKind);
    if (better) (best, bestLength, bestKind) = (product, productWords.length, sameKind);
  }
  return best;
}

/// As palavras que dizem o que o produto é, na ordem do nome: sem número,
/// tamanho, embalagem nem ligação.
List<String> _significantWords(Iterable<String> words) => [
  for (final word in words)
    if (!_isNumber(word) && !_connectors.contains(word) && !_packaging.contains(word) && !_units.contains(word)) word,
];

/// A categoria do catálogo e o tipo do produto da pessoa, deduzido do nome,
/// combinam: são o mesmo, ou um deles não diz (sem categoria, "outros"), ou
/// diz só como o produto é vendido (prateleira, congelado: o leite longa
/// vida é leite). Laticínio e doce também combinam, porque o catálogo põe
/// iogurte e creme de leite num ou noutro.
bool _kindsAgree(ProductKind? catalog, ProductKind product) {
  if (catalog == null || catalog == product) return true;
  const loose = {ProductKind.other, ProductKind.shelfStable, ProductKind.frozen};
  if (loose.contains(catalog) || loose.contains(product)) return true;
  return {catalog, product}.containsAll(const {ProductKind.dairy, ProductKind.sweets});
}

/// Palavras que, a mais no nome do catálogo, mudam o tipo do produto: o
/// leite condensado não é leite, nem o arroz carreteiro, arroz. Também os
/// sabores ([_flavors]): a "Fanta Uva" não é uva. E as palavras em espanhol
/// que o catálogo traz com código brasileiro ("Arroz con leche"), para não
/// cair num produto em português.
const _typeWords = {
  ..._flavors,
  'chocolate',
  'condensado',
  'condensada',
  'carreteiro',
  'tropeiro',
  'refrigerante',
  'suco',
  'nectar',
  'bebida',
  'fermentado',
  'fermentada',
  'sabor',
  'sabores',
  'pronto',
  'pronta',
  'temperado',
  'temperada',
  'cozido',
  'cozida',
  'recheado',
  'recheada',
  'empanado',
  'empanada',
  'instantaneo',
  'instantanea',
  'soluvel',
  'achocolatado',
  'molho',
  'caldo',
  'tempero',
  'creme',
  'doce',
  'mel',
  'queijo',
  'passa',
  'polpa',
  'geleia',
  'gelatina',
  'pudim',
  'sorvete',
  'bolo',
  'farofa',
  'pipoca',
  'palha',
  'frita',
  'chips',
  'amendoa',
  'amendoas',
  'con',
  'leche',
  'crema',
  'polvo',
  'jugo',
  'dulce',
};

/// A marca do catálogo, que pode vir com várias separadas por vírgula
/// ("Tio João, Josapar") ou em caixa alta ("TIO JOÃO"): fica a primeira.
/// Uma marca conhecida sem acento ("NESTLE", "Tio Joao") ganha a grafia de
/// [_brandSpellings] ("Nestlé", "Tio João", G13); outra em caixa alta vira
/// só a inicial maiúscula.
String? _catalogBrand(String? brand) {
  final first = brand?.split(',').first.trim() ?? '';
  if (first.isEmpty) return null;
  final folded = foldText(first);
  final hasAccent = folded != first.toLowerCase();
  if (!hasAccent) {
    if (_brandSpellings[_words(folded).join(' ')] case final spelling?) return spelling;
  }
  final shouting = first == first.toUpperCase() && first != first.toLowerCase();
  if (!shouting) return first;
  return first.toLowerCase().split(' ').map(_capitalize).join(' ');
}

/// O nome do produto novo sugerido pelo nome do catálogo: sem a marca
/// ([_withoutBrand]), e com o recorte das etiquetas ([productNameFromLabel]).
/// Se só sobra a marca ("Nescau"), ela é o nome.
///
/// Se sem a marca sobra só um sabor, uma linha ou uma palavra que não é de
/// produto ("Fanta Uva" daria "Uva", "Heineken Original", "Original"), a
/// marca fica: "Fanta uva", "Heineken" (G13). A fruta "Uva" com o preço de
/// um refrigerante é pior que um nome com marca. Uma palavra que é produto
/// ("Arroz Tio João") fica sozinha.
String _catalogProductName(String name, {required String? brand}) {
  final rest = _withoutBrand(name, brand: brand);
  final cut = productNameFromLabel(rest);
  if (cut.isEmpty) return productNameFromLabel(name);
  if (rest == name || !_isHalfName(cut)) return cut;
  final withBrand = _labelName(name, keepBrands: true, skip: _plainVariants);
  return withBrand.isNotEmpty ? withBrand : cut;
}

/// [name] sem a [brand]: a marca inteira, onde ela aparece junta ("Café
/// Torrado Café Brasileiro" perde só o segundo "Café"); senão, cada palavra
/// dela, menos a primeira do nome, que costuma ser o produto ("Feijão
/// Carioca Camil", marca "Camil Alimentos").
String _withoutBrand(String name, {required String? brand}) {
  final brandWords = brand == null ? const <String>[] : _words(foldText(brand));
  final tokens = _tokens(name);
  if (brandWords.isEmpty) return name;
  final words = [for (final token in tokens) token.word];
  var drop = <int>{};
  for (var i = 0; i + brandWords.length <= words.length && drop.isEmpty; i++) {
    var same = true;
    for (var j = 0; j < brandWords.length && same; j++) {
      same = words[i + j] == brandWords[j];
    }
    if (same) drop = {for (var j = i; j < i + brandWords.length; j++) j};
  }
  if (drop.isEmpty) {
    final set = brandWords.toSet();
    drop = {
      for (var i = 1; i < words.length; i++)
        if (set.contains(words[i])) i,
    };
  }
  if (drop.isEmpty) return name;
  return [
    for (var i = 0; i < tokens.length; i++)
      if (!drop.contains(i)) tokens[i].text,
  ].join(' ');
}

/// O recorte [cut] diz só a metade do nome (G13): uma palavra só que é
/// sabor, linha ou desconhecida ("Uva", "Original", "Dark"), ou só sabores e
/// linhas ("Uva zero"). Uma palavra de produto ("Arroz", "Refrigerante")
/// basta.
bool _isHalfName(String cut) {
  final words = _words(foldText(cut)).where((word) => !_connectors.contains(word)).toList();
  if (words.isEmpty) return false;
  if (words.every((word) => _flavors.contains(word) || _variants.contains(word))) return true;
  return words.length == 1 && ProductKind.of(words.single) == ProductKind.other;
}

/// Sabores, que sozinhos não nomeiam o produto da marca ("Fanta Uva"). Fica
/// de fora o que também é produto de prateleira ("chocolate", "banana").
const _flavors = {
  'uva',
  'morango',
  'abacaxi',
  'maracuja',
  'pessego',
  'manga',
  'goiaba',
  'caju',
  'cereja',
  'framboesa',
  'amora',
  'limao',
  'laranja',
  'tangerina',
  'mexerica',
  'coco',
  'baunilha',
  'menta',
  'hortela',
  'canela',
  'cola',
  'guarana',
  'tutti',
  'frutti',
  'caramelo',
  'frutas',
  'vermelhas',
};

/// Linhas e versões de um produto de marca ("Heineken Original", "Kit Kat
/// Dark"), que sozinhas não nomeiam nada.
const _variants = {
  ..._plainVariants,
  'zero',
  'light',
  'diet',
  'dark',
  'extra',
  'forte',
  'extraforte',
  'suave',
  'intenso',
  'gold',
  'premium',
  'black',
  'white',
  'puro',
  'plus',
  'max',
};

/// As linhas que são o próprio produto da marca, sem nada a mais: com a
/// marca no nome, elas saem ("Heineken Original" é "Heineken"). "Sabor"
/// também sai ("Fanta sabor laranja" é "Fanta laranja").
const _plainVariants = {'original', 'tradicional', 'classico', 'classic', 'sabor'};

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

/// Marcas comuns no mercado, sem acento e em minúsculas, com a grafia
/// delas. O recorte da etiqueta só tira uma palavra como marca se ela
/// estiver aqui: uma marca que fica no nome custa menos que uma variedade
/// que some (G6). Ficam de fora as marcas que também são palavras de produto
/// ("prato", "galo").
const _knownBrands = {
  'adria': 'Adria',
  'aurora': 'Aurora',
  'barilla': 'Barilla',
  'batavo': 'Batavo',
  'bauducco': 'Bauducco',
  'camil': 'Camil',
  'catupiry': 'Catupiry',
  'coqueiro': 'Coqueiro',
  'danone': 'Danone',
  'dona benta': 'Dona Benta',
  'elege': 'Elegê',
  'fugini': 'Fugini',
  'friboi': 'Friboi',
  'gomes da costa': 'Gomes da Costa',
  'heinz': 'Heinz',
  'hellmanns': "Hellmann's",
  'italac': 'Italac',
  'itambe': 'Itambé',
  'kicaldo': 'Kicaldo',
  'knorr': 'Knorr',
  'liza': 'Liza',
  'maggi': 'Maggi',
  'marilan': 'Marilan',
  'melitta': 'Melitta',
  'moca': 'Moça',
  'nescau': 'Nescau',
  'nestle': 'Nestlé',
  'ninho': 'Ninho',
  'omo': 'Omo',
  'parmalat': 'Parmalat',
  'perdigao': 'Perdigão',
  'pilao': 'Pilão',
  'piracanjuba': 'Piracanjuba',
  'piraque': 'Piraquê',
  'polenghi': 'Polenghi',
  'pomarola': 'Pomarola',
  'qualy': 'Qualy',
  'renata': 'Renata',
  'sadia': 'Sadia',
  'santa clara': 'Santa Clara',
  'seara': 'Seara',
  'soya': 'Soya',
  'swift': 'Swift',
  'tio joao': 'Tio João',
  'tres coracoes': 'Três Corações',
  'uniao': 'União',
  'vitarella': 'Vitarella',
  'yoki': 'Yoki',
  'ype': 'Ypê',
};

/// A grafia das marcas que o catálogo escreve sem acento ("NESTLE", "TIO
/// JOAO"), para a embalagem não nascer com "Nestle" (G13): as de
/// [_knownBrands] e outras que o catálogo traz em caixa alta, com a grafia
/// mais comum nele mesmo. Estas não saem do nome da etiqueta, por serem
/// também palavras comuns ("leão", "américa").
const _brandSpellings = {
  ..._knownBrands,
  '3 coracoes': '3 Corações',
  'casa suica': 'Casa Suíça',
  'cepera': 'Cepêra',
  'cha leao': 'Chá Leão',
  'dalia': 'Dália',
  'jundia': 'Jundiá',
  'leao': 'Leão',
  'mae terra': 'Mãe Terra',
  'matte leao': 'Matte Leão',
  'nescafe': 'Nescafé',
  'nescafe dolce gusto': 'Nescafé Dolce Gusto',
  'president': 'Président',
  'qualita': 'Qualitá',
  'sazon': 'Sazón',
  'vale fertil': 'Vale Fértil',
  'xando': 'Xandô',
};

final _knownBrandWords = [for (final brand in _knownBrands.keys) brand.split(' ')];

/// O acento das palavras de mercado mais comuns, que a etiqueta escreve sem
/// ("FEIJAO"), para o nome do produto novo não nascer "Feijao" (G6). Só
/// palavras sem outra leitura no mercado: uma palavra fora daqui fica como
/// veio, sem acento inventado.
const _accents = {
  'abobora': 'abóbora',
  'acai': 'açaí',
  'acem': 'acém',
  'acucar': 'açúcar',
  'agriao': 'agrião',
  'agua': 'água',
  'alcool': 'álcool',
  'almeirao': 'almeirão',
  'almondega': 'almôndega',
  'amendoa': 'amêndoa',
  'brocolis': 'brócolis',
  'cafe': 'café',
  'camarao': 'camarão',
  'cha': 'chá',
  'contrafile': 'contrafilé',
  'coracao': 'coração',
  'coxao': 'coxão',
  'cupuacu': 'cupuaçu',
  'feijao': 'feijão',
  'figado': 'fígado',
  'file': 'filé',
  'frances': 'francês',
  'fuba': 'fubá',
  'grao': 'grão',
  'guarana': 'guaraná',
  'graos': 'grãos',
  'hamburguer': 'hambúrguer',
  'higienico': 'higiênico',
  'hortela': 'hortelã',
  'jilo': 'jiló',
  'limao': 'limão',
  'linguica': 'linguiça',
  'maca': 'maçã',
  'macarrao': 'macarrão',
  'mamao': 'mamão',
  'manjericao': 'manjericão',
  'maracuja': 'maracujá',
  'melao': 'melão',
  'moida': 'moída',
  'moido': 'moído',
  'musculo': 'músculo',
  'oleo': 'óleo',
  'padrao': 'padrão',
  'pao': 'pão',
  'parmesao': 'parmesão',
  'pessego': 'pêssego',
  'pimentao': 'pimentão',
  'po': 'pó',
  'pure': 'purê',
  'requeijao': 'requeijão',
  'rucula': 'rúcula',
  'sabao': 'sabão',
  'salmao': 'salmão',
  'suina': 'suína',
  'suino': 'suíno',
  'tilapia': 'tilápia',
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
String productNameFromLabel(String? nameHint) => _labelName(nameHint);

/// O recorte de [productNameFromLabel]. Com [keepBrands], as marcas de
/// [_knownBrands] ficam, com a grafia de [_brandSpellings] ("Nescafe" é
/// "Nescafé"), e as palavras de [skip] saem.
String _labelName(String? nameHint, {bool keepBrands = false, Set<String> skip = const {}}) {
  final hint = nameHint?.trim() ?? '';
  if (hint.isEmpty) return '';
  final tokens = _tokens(hint);
  final words = [for (final token in tokens) token.word];
  final (_, _, sizeWords) = _size(foldText(hint));
  final brands = keepBrands ? const <int>{} : _brandPositions(words);

  bool content(int i) {
    final word = words[i];
    final noise =
        _isNumber(word) ||
        sizeWords.contains(word) ||
        _units.contains(word) ||
        _packaging.contains(word) ||
        _connectors.contains(word) ||
        skip.contains(word);
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
    final brand = keepBrands ? _brandSpellings[token.word] : null;
    name.add(hasAccent ? token.text : brand ?? _accentWord(token.word));
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
