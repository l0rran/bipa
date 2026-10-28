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
/// * valores seguidos de unidade ("1,50 L") são quantidades, não preços,
///   exceto depois de "R$" ("R$ 8,99 KG", "R$ 4,99 UN");
/// * parcelas ("10X DE R$ 129,99") não são o preço;
/// * centavos sobrescritos lidos como linha à parte ("R$ 18" + ",99") são
///   juntados ao inteiro, quando o OCR informa a posição horizontal;
/// * marcadores "de/por" identificam preço normal e promocional;
/// * sem marcadores, vence o valor escrito com a maior fonte.
///
/// O resultado é sempre uma sugestão: a interface pede confirmação.
final class PriceTagParser {
  const PriceTagParser();

  /// Aceita milhar com ponto: "1.299,90".
  static final _decimalPrice = RegExp(r'(?<![\d.,])(\d{1,3}(?:\.\d{3})+|\d{1,4})\s?[,.]\s?(\d{2})(?!\d)');

  /// Centavos impressos separados e menores: "R$ 18 99".
  static final _splitCentsPrice = RegExp(r'R\$\s*(\d{1,4})\s+(\d{2})(?!\d)');

  static final _date = RegExp(r'\d{1,2}[/.-]\d{1,2}[/.-]\d{2,4}');

  static final _quantitySuffix = RegExp(
    r'^\s?(kg|g|gr|ml|l|lt|un|und)\b',
    caseSensitive: false,
  );

  static final _currencyBefore = RegExp(r'R\$\s*$');

  static final _installment = RegExp(r'\b\d{1,2}\s?x\s?(de\s+)?(r\$)?\s*$', caseSensitive: false);

  /// "R$ 1 0,99": o OCR separou os dígitos de um número de letras espaçadas.
  static final _spacedDigits = RegExp(r'(R\$\s?)(\d(?:\s\d){1,3})(?=\s?[,.]\s?\d{2}(?!\d))');

  static final _integerEnd = RegExp(r'(?<![\d,.])\d{1,4}$');
  static final _centsFragment = RegExp(r'^[,.]?\s?(\d{2})$');

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

  /// Linhas que nunca são o nome: preços, rótulos e condições da etiqueta.
  static final _nonNameMarker = RegExp(
    r'R\$|oferta|promo|pre[cçÇ]o|validade|v[aáÁ]lido'
    r'|\bleve\s+\d|\bpague\s+\d|\bvarejo\b|\batacado\b|\bunidades?\b|\bcada\b|\ba\s?partir\s+de\b'
    r'|\bcart[aãÃ]o\b|\bcred\b|\bclube\b|\bapp\b',
    caseSensitive: false,
  );

  /// Lixo típico de OCR: a mesma letra repetida ("oooooo", "iiiii").
  static final _repeatedLetter = RegExp(r'([A-Za-z])\1{3,}');

  static final _letter = RegExp('[A-Za-zÀ-ÿ]');
  static final _digitRun = RegExp(r'(?<!\d)\d[\d ]{6,18}\d(?!\d)');
  static final _whitespace = RegExp(r'\s+');

  PriceTagReading parse(List<OcrLine> lines, {Iterable<String> barcodes = const []}) {
    final ordered = _mergeCentsFragments([
      for (final line in lines)
        OcrLine(
          text: _normalize(line.text),
          top: line.top,
          height: line.height,
          left: line.left,
          width: line.width,
        ),
    ])..sort((a, b) => a.top.compareTo(b.top));

    final candidates = <_Candidate>[];
    final unitPriceCandidates = <_Candidate>[];
    for (final line in ordered) {
      final text = line.text.replaceAll(_date, ' ');
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
      final prefix = text.substring(0, match.start);
      final isQuantity = _quantitySuffix.hasMatch(text.substring(match.end)) && !_currencyBefore.hasMatch(prefix);
      if (isQuantity || _installment.hasMatch(prefix)) continue;
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
    final cents = int.parse(match.group(1)!.replaceAll('.', '')) * 100 + int.parse(match.group(2)!);
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
      final text = line.text;
      if (_nonNameMarker.hasMatch(text) || _findPrices(text, 0).isNotEmpty) continue;

      final letters = _letter.allMatches(text).length;
      final visibleChars = text.replaceAll(' ', '').length;
      final isNoise = _repeatedLetter.hasMatch(text);
      if (letters >= 4 && letters / visibleChars >= 0.5 && !isNoise) return _titleCase(text);
    }
    return null;
  }

  static String _normalize(String text) => text
      .replaceAll('\u00a0', ' ')
      .replaceAll(RegExp(r'R\s*\$'), r'R$')
      // O OCR frequentemente lê "R$" como "RS" ou "R5".
      .replaceAll(RegExp(r'\bR[S5]\s*(?=\d)'), r'R$ ')
      .replaceAll(_whitespace, ' ')
      .trim()
      .replaceAllMapped(_spacedDigits, (m) => '${m[1]}${m[2]!.replaceAll(' ', '')}');

  /// Junta "R$ 18" e ",99" quando os centavos sobrescritos, menores e
  /// alinhados ao topo do inteiro, chegam como uma linha à parte.
  static List<OcrLine> _mergeCentsFragments(List<OcrLine> lines) {
    final merged = <OcrLine>[];
    final used = <int>{};
    for (var i = 0; i < lines.length; i++) {
      if (used.contains(i)) continue;
      var line = lines[i];
      final (left, right) = (line.left, line.right);
      if (left != null && right != null && _integerEnd.hasMatch(line.text) && !_decimalPrice.hasMatch(line.text)) {
        for (var j = 0; j < lines.length; j++) {
          final fragment = lines[j];
          final (fragmentLeft, fragmentRight) = (fragment.left, fragment.right);
          if (j == i || used.contains(j) || fragmentLeft == null || fragmentRight == null) continue;
          final cents = _centsFragment.firstMatch(fragment.text);
          if (cents == null || fragment.height >= 0.8 * line.height) continue;

          final gap = fragmentLeft - right;
          final besideInteger = gap >= -0.1 * line.height && gap <= 0.6 * line.height;
          final alignedToTop =
              fragment.top >= line.top - 0.25 * line.height && fragment.top <= line.top + 0.5 * line.height;
          if (besideInteger && alignedToTop) {
            line = OcrLine(
              text: '${line.text},${cents[1]}',
              top: line.top,
              height: line.height,
              left: left,
              width: fragmentRight - left,
            );
            used.add(j);
            break;
          }
        }
      }
      merged.add(line);
    }
    return merged;
  }

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
