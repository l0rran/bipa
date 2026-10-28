import 'package:bipa/core/catalog/text_fold.dart';
import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:bipa/features/products/domain/product.dart';
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
  final matches = RegExp(r'(\d+(?:[.,]\d+)?)\s?(kg|kgs|g|gr|grs|ml|l|lt|lts|litros?|un|und|unid|unidades?)\b')
      .allMatches(folded)
      .toList();
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

/// Palavras que descrevem o produto, não a marca.
const _descriptors = {
  'de', 'da', 'do', 'com', 'sem', 'e', 'tipo', 'tp', 'pct', 'pacote', 'cx', 'caixa', 'lata', 'garrafa',
  'branco', 'branca', 'integral', 'parboilizado', 'tradicional', 'extra', 'forte', 'suave', 'refinado', 'refinada',
  'cristal', 'carioca', 'preto', 'uht', 'desnatado', 'semidesnatado', 'light', 'zero', 'original', 'classico',
  'especial', 'premium', 'novo', 'nova', 'po', 'liquido', 'em', 'graos', 'moido', 'torrado', 'vacuo',
};
