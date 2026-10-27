import 'package:bipa/core/money/money.dart';
import 'package:bipa/features/prices/domain/price_tag.dart';
import 'package:bipa/features/products/domain/gtin.dart';

/// Interpreta o texto reconhecido por OCR em uma etiqueta de gôndola.
///
/// Etiquetas costumam ter vários valores (preço normal, promocional, preço por
/// quilo) e o OCR comete erros. As heurísticas são:
///
/// * linhas de preço por unidade de medida ("R$ 5,58/kg") são ignoradas, a
///   menos que sejam o único preço (produtos vendidos a granel);
/// * valores seguidos de unidade ("1,50 L") são quantidades, não preços;
/// * marcadores "de/por" identificam preço normal e promocional;
/// * sem marcadores, vence o valor escrito com a maior fonte.
///
/// O resultado é sempre uma sugestão: a interface pede confirmação.
final class PriceTagParser {
  const PriceTagParser();

  static final _decimalPrice = RegExp(r'(?<![\d.,])(\d{1,4})\s?[,.]\s?(\d{2})(?!\d)');

  /// Centavos impressos separados e menores: "R$ 18 99".
  static final _splitCentsPrice = RegExp(r'R\$\s*(\d{1,4})\s+(\d{2})(?!\d)');

  static final _date = RegExp(r'\d{1,2}[/.-]\d{1,2}[/.-]\d{2,4}');

  static final _quantitySuffix = RegExp(
    r'^\s?(kg|g|gr|ml|l|lt|un|und)\b',
    caseSensitive: false,
  );

  static final _unitPriceMarker = RegExp(
    r'/\s?(kg|g|l|lt|ml|un|100\s?(g|ml))\b'
    r'|pre[cçÇ]o\s+(por|p/)\s'
    r'|\bp/\s?(kg|l|lt)\b'
    r'|\bpor\s+(kg|litro|quilo)\b',
    caseSensitive: false,
  );

  static final _regularMarker = RegExp(
    r'\b(de|normal|antes|era)\b[\s:]*(r\$)?\s*$',
    caseSensitive: false,
  );

  static final _promoMarker = RegExp(
    r'\b(por|oferta|promo[cçÇ][aãÃ]o|clube)\b[\s:]*(r\$)?\s*$',
    caseSensitive: false,
  );

  static final _nonNameMarker = RegExp(
    r'R\$|oferta|promo|pre[cçÇ]o|validade|v[aáÁ]lido',
    caseSensitive: false,
  );

  static final _letter = RegExp('[A-Za-zÀ-ÿ]');
  static final _digitRun = RegExp(r'(?<!\d)\d[\d ]{6,18}\d(?!\d)');
  static final _whitespace = RegExp(r'\s+');

  PriceTagReading parse(List<OcrLine> lines, {Iterable<String> barcodes = const []}) {
    final ordered = [...lines]..sort((a, b) => a.top.compareTo(b.top));

    final candidates = <_Candidate>[];
    final unitPriceCandidates = <_Candidate>[];
    for (final line in ordered) {
      final text = _normalize(line.text).replaceAll(_date, ' ');
      if (text.trim().isEmpty) continue;
      final target = _unitPriceMarker.hasMatch(text) ? unitPriceCandidates : candidates;
      target.addAll(_findPrices(text, line.height));
    }

    // Produtos a granel só têm preço por quilo: nesse caso ele é o preço.
    final pool = candidates.isNotEmpty ? candidates : unitPriceCandidates;
    final main = _choosePrice(pool);

    return PriceTagReading(
      price: main?.money,
      regularPrice: main == null ? null : _chooseRegularPrice(pool, main),
      barcode: _chooseBarcode(barcodes, ordered),
      productNameHint: _productNameHint(ordered),
      candidates: {for (final candidate in pool) candidate.money}.toList(growable: false),
    );
  }

  _Candidate? _choosePrice(List<_Candidate> pool) {
    if (pool.isEmpty) return null;
    final promotional = pool.where((c) => c.role == _Role.promotional).toList();
    final notRegular = pool.where((c) => c.role != _Role.regular).toList();
    final eligible = promotional.isNotEmpty
        ? promotional
        : (notRegular.isNotEmpty ? notRegular : pool);
    // Em caso de empate na altura, mantém o primeiro (mais acima na etiqueta).
    return eligible.reduce((best, c) => c.height > best.height ? c : best);
  }

  Money? _chooseRegularPrice(List<_Candidate> pool, _Candidate main) {
    Money? regular;
    for (final candidate in pool) {
      final isHigherRegular = candidate.role == _Role.regular && candidate.money > main.money;
      if (isHigherRegular && (regular == null || candidate.money > regular)) {
        regular = candidate.money;
      }
    }
    return regular;
  }

  Iterable<_Candidate> _findPrices(String text, double height) sync* {
    var foundDecimal = false;
    for (final match in _decimalPrice.allMatches(text)) {
      if (_quantitySuffix.hasMatch(text.substring(match.end))) continue;
      final candidate = _toCandidate(text, match, height);
      if (candidate != null) {
        foundDecimal = true;
        yield candidate;
      }
    }
    if (foundDecimal) return;

    for (final match in _splitCentsPrice.allMatches(text)) {
      final candidate = _toCandidate(text, match, height);
      if (candidate != null) yield candidate;
    }
  }

  _Candidate? _toCandidate(String text, RegExpMatch match, double height) {
    final cents = int.parse(match.group(1)!) * 100 + int.parse(match.group(2)!);
    if (cents <= 0) return null;

    final prefix = text.substring(0, match.start);
    final role = _promoMarker.hasMatch(prefix)
        ? _Role.promotional
        : _regularMarker.hasMatch(prefix)
        ? _Role.regular
        : _Role.neutral;
    return _Candidate(Money.cents(cents), height, role);
  }

  String? _chooseBarcode(Iterable<String> barcodes, List<OcrLine> lines) {
    final scanned = barcodes.map(Gtin.normalize).nonNulls.firstOrNull;
    if (scanned != null) return scanned;

    // Fallback: dígitos impressos abaixo das barras. Exige 12+ dígitos para
    // não confundir datas ou outros números curtos com um EAN-8.
    for (final line in lines) {
      for (final match in _digitRun.allMatches(line.text)) {
        final code = Gtin.normalize(match.group(0)!);
        if (code != null && code.length >= 12) return code;
      }
    }
    return null;
  }

  String? _productNameHint(List<OcrLine> lines) {
    for (final line in lines) {
      final text = _normalize(line.text);
      if (_nonNameMarker.hasMatch(text) || _findPrices(text, 0).isNotEmpty) continue;

      final letters = _letter.allMatches(text).length;
      final visibleChars = text.replaceAll(' ', '').length;
      if (letters >= 4 && letters / visibleChars >= 0.5) return _titleCase(text);
    }
    return null;
  }

  static String _normalize(String text) => text
      .replaceAll(' ', ' ')
      .replaceAll(RegExp(r'R\s*\$'), r'R$')
      // O OCR frequentemente lê "R$" como "RS" ou "R5".
      .replaceAll(RegExp(r'\bR[S5]\s*(?=\d)'), r'R$ ')
      .replaceAll(_whitespace, ' ')
      .trim();

  static String _titleCase(String text) => text
      .split(' ')
      .map((word) => word.isEmpty ? word : word[0].toUpperCase() + word.substring(1).toLowerCase())
      .join(' ');
}

enum _Role { neutral, promotional, regular }

final class _Candidate {
  const _Candidate(this.money, this.height, this.role);

  final Money money;
  final double height;
  final _Role role;
}
