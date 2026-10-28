import 'dart:math' as math;

import 'package:bipa/core/money/money.dart';
import 'package:bipa/features/prices/domain/price_condition.dart';
import 'package:bipa/features/prices/domain/price_tag.dart';
import 'package:bipa/features/products/domain/gtin.dart';

/// Interpreta o texto reconhecido por OCR em uma etiqueta de gôndola.
///
/// Etiquetas costumam ter vários valores (preço normal, promocional, preço por
/// quilo, atacado, cartão da loja) e o OCR comete erros. As heurísticas são:
///
/// * linhas de preço por unidade de medida ("R$ 5,58/kg") são ignoradas, a
///   menos que sejam o único preço (produtos vendidos a granel);
/// * valores seguidos de unidade ("1,50 L") são quantidades, não preços,
///   exceto depois de "R$" ("R$ 8,99 KG", "R$ 4,99 UN");
/// * parcelas ("10X DE R$ 129,99") não são o preço;
/// * centavos sobrescritos lidos como linha à parte ("R$ 18" + ",99") são
///   juntados ao inteiro, quando o OCR informa a posição horizontal;
/// * marcadores "de/por" identificam preço normal e promocional;
/// * rótulos de condição ("ATACADO", "A PARTIR DE 10 UNIDADES", "PASSAÍ
///   CRED", "PREÇO CLUBE") valem para o preço da mesma linha ou da mesma
///   coluna, logo acima ou abaixo (ADR 0011);
/// * em cada condição, vence o valor escrito com a maior fonte;
/// * sem nenhum rótulo lido, uma etiqueta com mais de um preço do mesmo
///   tamanho não diz qual é o de varejo: nenhum é escolhido, e os valores
///   ficam como candidatos para a pessoa tocar no certo.
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

  /// Número de 3 ou 4 dígitos logo depois de um preço: "13,89 1535".
  static final _missingSeparator = RegExp(r'^\s+(\d{1,2})(\d{2})(?![\d.,])');

  static final _integerEnd =RegExp(r'(?<![\d,.])\d{1,4}$');
  static final _centsFragment = RegExp(r'^[,.]?\s?(\d{2})$');

  static final _unitPriceMarker = RegExp(
    r'/\s?(kg|g|l|lt|ml|un|100\s?(g|ml))\b'
    r'|pre[cçÇ]o\s+(por|p/)\s'
    r'|\bp/\s?(kg|l|lt)\b'
    r'|\bpor\s+(kg|litro|quilo)\b',
    caseSensitive: false,
  );

  /// "kg" logo depois do valor: "8,99 KG", "39,90 /kg", "8,99 o kg".
  static final _perKiloAfter = RegExp(r'^\s?(o\s+)?/?\s?(kg|quilo)\b', caseSensitive: false);

  /// A linha inteira fala do preço por quilo: "PREÇO POR KG", "R$ 5,58/kg".
  static final _perKiloMarker = RegExp(
    r'/\s?kg\b|\bp/\s?kg\b|\bpor\s+(kg|quilo)\b',
    caseSensitive: false,
  );

  static final _regularMarker = RegExp(
    r'\b(de|normal|antes|era)\b[\s:]*(r\$)?\s*$',
    caseSensitive: false,
  );

  static final _promoMarker = RegExp(
    r'\b(por|oferta|promo[cçÇ][aãÃ]o)\b[\s:]*(r\$)?\s*$',
    caseSensitive: false,
  );

  /// Rótulos que ocupam uma linha só: "POR", "DE R$", "OFERTA".
  static final _promoLabel = RegExp(r'^(por|oferta|promo[cçÇ][aãÃ]o)[\s:]*(r\$)?$', caseSensitive: false);
  static final _regularLabel = RegExp(r'^(de|normal|antes|era|pre[cçÇ]o normal)[\s:]*(r\$)?$', caseSensitive: false);

  static final _wholesaleMarker = RegExp(r'\batacado\b|\ba\s?partir\s+de\b|\bacima\s+de\b', caseSensitive: false);

  static final _loyaltyMarker = RegExp(
    r'\bcart[aãÃ]o\b|\bcred\b|\bclube\b|\bapp\b|\baplicativo\b|\bcliente\b|\bfidelidade\b',
    caseSensitive: false,
  );

  /// Quantidade mínima do atacado numa linha própria: "10", "06 UN", "12 UNIDADES".
  static final _quantityOnly = RegExp(r'^(\d{1,3})\s*(un|und|unid\w*)?\.?$', caseSensitive: false);
  static final _number = RegExp(r'(?<![\d,.])(\d{1,3})(?![\d,.])');

  /// Linhas que nunca são o nome: preços, rótulos e condições da etiqueta.
  static final _nonNameMarker = RegExp(
    r'R\$|oferta|promo|pre[cçÇ]o|validade|v[aáÁ]lido'
    r'|\bleve\s+\d|\bpague\s+\d|\bvarejo\b|\bunidades?\b|\bcada\b',
    caseSensitive: false,
  );

  /// Lixo típico de OCR: a mesma letra repetida ("oooooo", "iiiii").
  static final _repeatedLetter = RegExp(r'([A-Za-z])\1{3,}');

  static final _letter = RegExp('[A-Za-zÀ-ÿ]');
  static final _digitRun = RegExp(r'(?<!\d)\d[\d ]{6,18}\d(?!\d)');
  static final _whitespace = RegExp(r'\s+');

  /// Preços impressos bem menores que o maior (bloco de informações, preço
  /// por litro) continuam como candidatos, mas não viram ofertas.
  static const _offerMinHeightRatio = 0.35;

  /// Preços com pelo menos esta fração da altura do maior disputam o posto
  /// de principal: a fonte não basta para escolher entre eles.
  static const _sameSizeRatio = 0.8;

  /// Distância máxima, em alturas de linha, entre dois preços iguais lado a
  /// lado na mesma etiqueta (as colunas de atacado e cartão do Assaí).
  static const _twinMaxGapRatio = 6;

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
    final texts = [for (final line in ordered) line.text.replaceAll(_date, ' ').trim()];

    final priceLines = [
      for (var i = 0; i < ordered.length; i++)
        if (texts[i].isNotEmpty && _findPrices(texts[i], 0).isNotEmpty) i,
    ];
    final labels = _labelsByPriceLine(ordered, texts, priceLines);

    final candidates = <_Candidate>[];
    final unitPriceCandidates = <_Candidate>[];
    for (final i in priceLines) {
      final isUnitPrice = _unitPriceMarker.hasMatch(texts[i]);
      final found = _findPrices(texts[i], ordered[i].height, labels[i] ?? _Labels.none, ordered[i]);
      // Na linha do preço por quilo, todo valor é por quilo.
      final perKiloLine = isUnitPrice && _perKiloMarker.hasMatch(texts[i]);
      (isUnitPrice ? unitPriceCandidates : candidates).addAll([
        for (final candidate in found) perKiloLine ? candidate.asPerKilo() : candidate,
      ]);
    }

    // Produtos a granel só têm preço por quilo: nesse caso ele é o preço.
    final pool = candidates.isNotEmpty ? candidates : unitPriceCandidates;
    final offers = _isUnlabeledMultiPrice(pool) ? const <PriceOffer>[] : _offers(pool);
    final main = offers.firstOrNull;
    final perKilo =
        main != null &&
        pool.any((c) => c.perKilo && c.money == main.price && c.condition == main.condition);

    return PriceTagReading(
      price: main?.price,
      regularPrice: main?.regularPrice,
      barcode: _chooseBarcode(barcodes, ordered),
      productNameHint: _productNameHint(ordered),
      candidates: {for (final candidate in pool) candidate.money}.toList(growable: false),
      offers: offers,
      perKilo: perKilo,
    );
  }

  /// Etiqueta com mais de um preço e nenhum rótulo lido ("ATACADO", "CRED",
  /// "DE/POR"...). Escolher um seria gravar o preço do cartão ou do atacado
  /// como se fosse o de varejo, que é o erro mais caro para o histórico.
  ///
  /// Conta como mais de um preço: valores diferentes do mesmo tamanho, ou o
  /// mesmo valor repetido lado a lado (as colunas de atacado e cartão do
  /// Assaí, quando o varejo não foi lido). O mesmo valor longe, em outra
  /// etiqueta do quadro, não conta.
  bool _isUnlabeledMultiPrice(List<_Candidate> pool) {
    if (pool.isEmpty) return false;
    final tallest = pool.map((c) => c.height).reduce(math.max);
    final sameSize = pool.where((c) => c.height >= _sameSizeRatio * tallest).toList();
    if (sameSize.any((c) => c.role != _Role.neutral || c.condition is! AnyCustomer)) return false;
    if ({for (final c in sameSize) c.money}.length > 1) return true;

    for (var i = 0; i < sameSize.length; i++) {
      for (var j = i + 1; j < sameSize.length; j++) {
        if (_sideBySide(sameSize[i].line, sameSize[j].line)) return true;
      }
    }
    return false;
  }

  static bool _sideBySide(OcrLine? a, OcrLine? b) {
    if (a == null || b == null || identical(a, b)) return false;
    final (aLeft, aRight, bLeft, bRight) = (a.left, a.right, b.left, b.right);
    if (aLeft == null || aRight == null || bLeft == null || bRight == null) return false;

    final horizontalGap = math.max(aLeft, bLeft) - math.min(aRight, bRight);
    return _verticalGap(a, b) == 0 && horizontalGap <= _twinMaxGapRatio * math.max(a.height, b.height);
  }

  /// Uma oferta por condição, com a sem condição primeiro.
  List<PriceOffer> _offers(List<_Candidate> pool) {
    if (pool.isEmpty) return const [];
    final tallest = pool.map((c) => c.height).reduce(math.max);
    final byCondition = <PriceCondition, List<_Candidate>>{};
    for (final candidate in pool) {
      final isMainSize = candidate.height >= _offerMinHeightRatio * tallest;
      if (isMainSize || candidate.role == _Role.regular) {
        byCondition.putIfAbsent(candidate.condition, () => []).add(candidate);
      }
    }

    final offers = <PriceOffer>[];
    List<_Candidate>? orphanRegulars;
    for (final MapEntry(key: condition, value: group) in byCondition.entries) {
      // Um "de R$" solto, sem condição, não é uma oferta: é o preço normal da principal.
      final onlyRegular = group.every((c) => c.role == _Role.regular);
      if (onlyRegular && condition is AnyCustomer && byCondition.length > 1) {
        orphanRegulars = group;
        continue;
      }

      final best = _choosePrice(group);
      offers.add(PriceOffer(price: best.money, condition: condition, regularPrice: _chooseRegularPrice(group, best)));
    }
    final ordered = [
      ...offers.where((o) => o.condition is AnyCustomer),
      ...offers.where((o) => o.condition is LoyaltyMembers),
      ...offers.where((o) => o.condition is Wholesale),
    ];
    if (orphanRegulars != null && ordered.first.regularPrice == null) {
      final main = ordered.first;
      final regular = orphanRegulars.map((c) => c.money).reduce((a, b) => a > b ? a : b);
      if (regular > main.price) {
        ordered[0] = PriceOffer(price: main.price, condition: main.condition, regularPrice: regular);
      }
    }
    return ordered;
  }

  _Candidate _choosePrice(List<_Candidate> pool) {
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

  /// Rótulos em linhas próprias, agrupados pelo índice da linha de preço a que se referem.
  Map<int, _Labels> _labelsByPriceLine(List<OcrLine> lines, List<String> texts, List<int> priceLines) {
    final labels = <int, _Labels>{};
    for (var i = 0; i < lines.length; i++) {
      final text = texts[i];
      if (text.isEmpty || priceLines.contains(i)) continue;

      final found = _Labels(
        wholesale: _wholesaleMarker.hasMatch(text),
        loyalty: _loyaltyMarker.hasMatch(text),
        promotional: _promoLabel.hasMatch(text),
        regular: _regularLabel.hasMatch(text),
        minimumQuantity: _wholesaleMarker.hasMatch(text)
            ? (_quantityAfterWholesale(text) ?? _quantityNear(i, lines))
            : null,
      );
      if (found.isEmpty) continue;

      final target = _priceLineFor(i, lines, priceLines);
      if (target != null) labels[target] = (labels[target] ?? _Labels.none).merge(found);
    }
    return labels;
  }

  /// Linha de preço a que um rótulo se refere: a mais próxima na mesma coluna
  /// (acima ou abaixo) ou na mesma linha, à direita do rótulo.
  /// Sem posição horizontal, é a próxima linha de preço.
  int? _priceLineFor(int labelIndex, List<OcrLine> lines, List<int> priceLines) {
    final label = lines[labelIndex];
    final (labelLeft, labelRight) = (label.left, label.right);
    if (labelLeft == null || labelRight == null) {
      return priceLines.where((i) => i > labelIndex).firstOrNull;
    }

    int? best;
    double? bestGap;
    for (final i in priceLines) {
      final price = lines[i];
      final (priceLeft, priceRight) = (price.left, price.right);
      if (priceLeft == null || priceRight == null) continue;

      final sameColumn = math.min(labelRight, priceRight) - math.max(labelLeft, priceLeft) > 0;
      final verticalGap = _verticalGap(label, price);
      final sameRow = verticalGap == 0 && priceLeft - labelRight >= 0 && priceLeft - labelRight < price.height;
      if (!sameColumn && !sameRow) continue;

      final gap = sameRow ? 0.0 : verticalGap;
      if (gap <= 1.5 * price.height && (bestGap == null || gap < bestGap)) {
        best = i;
        bestGap = gap;
      }
    }
    return best;
  }

  /// Quantidade mínima impressa perto do rótulo, na mesma coluna:
  /// "A PARTIR DE" / "10" / "UNIDADES".
  int? _quantityNear(int labelIndex, List<OcrLine> lines) {
    final label = lines[labelIndex];
    for (var j = 0; j < lines.length; j++) {
      final match = _quantityOnly.firstMatch(lines[j].text);
      if (j == labelIndex || match == null) continue;

      final other = lines[j];
      final isNear = switch ((label.left, label.right, other.left, other.right)) {
        (final l1?, final r1?, final l2?, final r2?) =>
          math.min(r1, r2) - math.max(l1, l2) > 0 && _verticalGap(label, other) < 2 * label.height,
        _ => j == labelIndex + 1,
      };
      if (isNear) return _positiveOrNull(int.parse(match[1]!));
    }
    return null;
  }

  static int? _quantityAfterWholesale(String text) {
    final marker = _wholesaleMarker.firstMatch(text);
    if (marker == null) return null;
    final number = _number.firstMatch(text.substring(marker.end));
    return number == null ? null : _positiveOrNull(int.parse(number[1]!));
  }

  static int? _positiveOrNull(int value) => value > 0 ? value : null;

  static double _verticalGap(OcrLine a, OcrLine b) =>
      math.max(0.0, math.max(a.top, b.top) - math.min(a.bottom, b.bottom));

  Iterable<_Candidate> _findPrices(
    String text,
    double height, [
    _Labels labels = _Labels.none,
    OcrLine? line,
  ]) sync* {
    var foundDecimal = false;
    for (final match in _decimalPrice.allMatches(text)) {
      final prefix = text.substring(0, match.start);
      final isQuantity = _quantitySuffix.hasMatch(text.substring(match.end)) && !_currencyBefore.hasMatch(prefix);
      if (isQuantity || _installment.hasMatch(prefix)) continue;
      final candidate = _toCandidate(prefix, match, height, labels, line);
      if (candidate == null) continue;
      foundDecimal = true;
      yield _perKiloAfter.hasMatch(text.substring(match.end)) ? candidate.asPerKilo() : candidate;

      final neighbor = _neighborWithoutSeparator(text, match.end, candidate, height, labels, line);
      if (neighbor != null) yield neighbor;
    }
    if (foundDecimal) return;

    for (final match in _splitCentsPrice.allMatches(text)) {
      final candidate = _toCandidate(text.substring(0, match.start), match, height, labels, line);
      if (candidate != null) yield candidate;
    }
  }

  /// Preço vizinho lido sem a vírgula: em "13,89 1535", o OCR juntou dois
  /// preços da mesma altura e perdeu a vírgula do segundo (15,35). Só vale
  /// para um valor próximo do primeiro, para não pegar códigos e quantidades.
  _Candidate? _neighborWithoutSeparator(
    String text,
    int end,
    _Candidate previous,
    double height,
    _Labels labels,
    OcrLine? line,
  ) {
    final match = _missingSeparator.firstMatch(text.substring(end));
    if (match == null || _quantitySuffix.hasMatch(text.substring(end + match.end))) return null;

    final candidate = _toCandidate(text.substring(0, end + match.start), match, height, labels, line);
    final ratio = (candidate?.money.cents ?? 0) / previous.money.cents;
    return ratio >= 0.5 && ratio <= 2 ? candidate : null;
  }

  _Candidate? _toCandidate(String prefix, RegExpMatch match, double height, _Labels labels, OcrLine? line) {
    final cents = int.parse(match.group(1)!.replaceAll('.', '')) * 100 + int.parse(match.group(2)!);
    if (cents <= 0) return null;

    final role = _promoMarker.hasMatch(prefix)
        ? _Role.promotional
        : _regularMarker.hasMatch(prefix)
        ? _Role.regular
        : labels.promotional
        ? _Role.promotional
        : labels.regular
        ? _Role.regular
        : _Role.neutral;

    final PriceCondition condition;
    if (labels.wholesale || _wholesaleMarker.hasMatch(prefix)) {
      condition = Wholesale(minimumQuantity: _quantityAfterWholesale(prefix) ?? labels.minimumQuantity);
    } else if (labels.loyalty || _loyaltyMarker.hasMatch(prefix)) {
      condition = const LoyaltyMembers();
    } else {
      condition = const AnyCustomer();
    }
    return _Candidate(Money.cents(cents), height, role, condition, line);
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
      final isLabel =
          _nonNameMarker.hasMatch(text) || _wholesaleMarker.hasMatch(text) || _loyaltyMarker.hasMatch(text);
      if (isLabel || _findPrices(text, 0).isNotEmpty) continue;

      final letters = _letter.allMatches(text).length;
      final visibleChars = text.replaceAll(' ', '').length;
      final isNoise = _repeatedLetter.hasMatch(text);
      if (letters >= 4 && letters / visibleChars >= 0.5 && !isNoise) return _titleCase(text);
    }
    return null;
  }

  static String _normalize(String text) => text
      .replaceAll(' ', ' ')
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
  const _Candidate(this.money, this.height, this.role, this.condition, this.line, {this.perKilo = false});

  final Money money;
  final double height;
  final _Role role;
  final PriceCondition condition;

  /// Linha de onde o valor saiu, para saber se dois preços estão lado a lado.
  final OcrLine? line;

  /// O valor é por quilo ("8,99 KG").
  final bool perKilo;

  _Candidate asPerKilo() => _Candidate(money, height, role, condition, line, perKilo: true);
}

/// O que os rótulos em linhas próprias dizem sobre um preço.
final class _Labels {
  const _Labels({
    this.wholesale = false,
    this.loyalty = false,
    this.promotional = false,
    this.regular = false,
    this.minimumQuantity,
  });

  static const none = _Labels();

  final bool wholesale;
  final bool loyalty;
  final bool promotional;
  final bool regular;
  final int? minimumQuantity;

  bool get isEmpty => !wholesale && !loyalty && !promotional && !regular;

  _Labels merge(_Labels other) => _Labels(
    wholesale: wholesale || other.wholesale,
    loyalty: loyalty || other.loyalty,
    promotional: promotional || other.promotional,
    regular: regular || other.regular,
    minimumQuantity: minimumQuantity ?? other.minimumQuantity,
  );
}
