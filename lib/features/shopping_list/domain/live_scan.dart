import 'package:bipa/core/money/money.dart';
import 'package:bipa/features/prices/domain/price_condition.dart';
import 'package:bipa/features/prices/domain/price_tag.dart';
import 'package:bipa/features/products/domain/gtin.dart';
import 'package:meta/meta.dart';

/// O que um quadro da câmera mostrou: os códigos de barras e a leitura do
/// texto dentro da moldura, os dois do mesmo quadro (ADR 0012).
@immutable
final class LiveFrame {
  const LiveFrame({required this.at, this.barcodes = const [], this.tag = PriceTagReading.empty});

  final DateTime at;
  final List<String> barcodes;
  final PriceTagReading tag;

  /// O preço de varejo da etiqueta, se o quadro tem um. Etiqueta só com preço
  /// de clube, de cartão ou de atacado não serve ao vivo: na dúvida, nada é
  /// escolhido.
  PriceOffer? get retailOffer => tag.offers.where((offer) => offer.condition is AnyCustomer).firstOrNull;

  /// O primeiro código válido (dígito verificador conferido).
  String? get validBarcode => barcodes.where(Gtin.isValid).firstOrNull;
}

/// O que a leitura ao vivo concluiu depois de alguns quadros.
sealed class LiveScanEvent {
  const LiveScanEvent();
}

/// Um produto foi bipado: o código apareceu sem etiqueta em volta.
final class ProductScanned extends LiveScanEvent {
  const ProductScanned(this.barcode);

  final String barcode;

  @override
  bool operator ==(Object other) => other is ProductScanned && other.barcode == barcode;

  @override
  int get hashCode => barcode.hashCode;

  @override
  String toString() => 'ProductScanned($barcode)';
}

/// Uma etiqueta foi lida: o mesmo preço de varejo se repetiu em quadros
/// seguidos. [barcode] é o código impresso na etiqueta, quando havia um.
final class TagPriceRead extends LiveScanEvent {
  const TagPriceRead({required this.price, this.barcode, this.otherOffers = const []});

  final Money price;
  final String? barcode;

  /// Os outros preços da mesma etiqueta (cartão, atacado), para o histórico.
  final List<PriceOffer> otherOffers;

  @override
  bool operator ==(Object other) =>
      other is TagPriceRead &&
      other.price == price &&
      other.barcode == barcode &&
      _sameOffers(other.otherOffers, otherOffers);

  @override
  int get hashCode => Object.hash(price, barcode, Object.hashAll(otherOffers));

  @override
  String toString() => 'TagPriceRead($price, $barcode, $otherOffers)';

  static bool _sameOffers(List<PriceOffer> a, List<PriceOffer> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Transforma quadros soltos em bipes e etiquetas lidas (ADR 0012).
///
/// * **Etiqueta:** um preço de varejo só vale quando se repete em
///   [tagAgreement] quadros dentro de [tagWindow]. Depois, o mesmo preço só
///   volta a valer quando some da moldura por [release], ou quando aparece
///   com outro código de etiqueta. Duas etiquetas vizinhas sem código e com o
///   mesmo preço, lidas sem pausa entre elas, valem uma vez só.
/// * **Código com preço no mesmo quadro é etiqueta,** não produto: não conta
///   como unidade bipada.
/// * **Bipe:** o código precisa aparecer sem preço em [codeAgreement] quadros,
///   e o primeiro deles precisa ter pelo menos [codeSettle]. Esse instante a
///   mais dá tempo para o OCR achar o preço de uma etiqueta com código, que o
///   leitor de código costuma ler antes. Para bipar de novo, o código precisa
///   sumir da moldura por [rescanPause].
/// * Um produto segurado na frente de uma etiqueta conta como etiqueta, e só
///   é bipado quando o preço sai da moldura.
/// * **Ao abrir a câmera**, o que já está na moldura não conta: nos primeiros
///   [startupQuiet], códigos e preços vistos ficam como já lidos e só voltam a
///   valer depois de sair da moldura. Assim, voltar do cadastro com o produto
///   ainda na frente não soma outra unidade (ver [restart]).
///
/// Não guarda estado entre compras: crie um por tela de carrinho.
final class LiveScanInterpreter {
  LiveScanInterpreter({
    this.tagAgreement = 3,
    this.tagWindow = const Duration(milliseconds: 1500),
    this.release = const Duration(seconds: 1),
    this.codeAgreement = 2,
    this.codeSettle = const Duration(milliseconds: 600),
    this.codeWindow = const Duration(seconds: 1),
    this.rescanPause = const Duration(milliseconds: 2500),
    this.tagCodeMemory = const Duration(seconds: 2),
    this.startupQuiet = const Duration(seconds: 1),
  }) : assert(tagAgreement > 0 && codeAgreement > 0),
       assert(codeSettle < codeWindow);

  final int tagAgreement;
  final Duration tagWindow;
  final Duration release;
  final int codeAgreement;
  final Duration codeSettle;
  final Duration codeWindow;
  final Duration rescanPause;

  /// Por quanto tempo um código visto numa etiqueta deixa de valer como bipe.
  final Duration tagCodeMemory;

  /// Quanto dura o silêncio depois de [restart].
  final Duration startupQuiet;

  DateTime? _quietUntil;

  final _priceHits = <_PriceHit>[];

  /// Preços já entregues, pelos centavos.
  final _deliveredPrices = <int, _Delivered>{};

  final _codeHits = <String, List<DateTime>>{};

  /// Códigos já bipados, com a última vez que apareceram na moldura.
  final _deliveredCodes = <String, DateTime>{};

  /// Códigos vistos em etiquetas, com a última vez.
  final _tagCodes = <String, DateTime>{};

  /// Analisa um quadro e devolve o que ele concluiu, na ordem: primeiro o
  /// bipe, depois a etiqueta.
  List<LiveScanEvent> add(LiveFrame frame) {
    final at = frame.at;
    _forgetOld(at);

    final retail = frame.retailOffer;
    final code = frame.validBarcode;
    final quietUntil = _quietUntil;
    if (quietUntil != null && at.isBefore(quietUntil)) {
      if (code != null) _deliveredCodes[code] = at;
      if (retail != null) _deliveredPrices[retail.price.cents] = _Delivered(lastSeen: at, barcode: code);
      return const [];
    }
    final events = <LiveScanEvent>[];

    if (code != null) {
      if (retail != null) {
        _tagCodes[code] = at;
        _codeHits.remove(code);
      } else if (_registerCode(code, at)) {
        events.add(ProductScanned(code));
      }
    }

    if (retail != null) {
      final read = _registerPrice(frame, retail, code);
      if (read != null) events.add(read);
    }
    return events;
  }

  /// Recomeça ao abrir a câmera, em [at]: esquece o que foi lido e ignora o
  /// que já está na moldura.
  void restart(DateTime at) {
    reset();
    _quietUntil = at.add(startupQuiet);
  }

  /// Esquece tudo.
  void reset() {
    _quietUntil = null;
    _priceHits.clear();
    _deliveredPrices.clear();
    _codeHits.clear();
    _deliveredCodes.clear();
    _tagCodes.clear();
  }

  bool _registerCode(String code, DateTime at) {
    final delivered = _deliveredCodes[code];
    if (delivered != null) {
      // A pausa se renova enquanto o código continua na moldura.
      _deliveredCodes[code] = at;
      return false;
    }
    final tagSeen = _tagCodes[code];
    if (tagSeen != null && at.difference(tagSeen) < tagCodeMemory) return false;

    final hits = (_codeHits[code] ??= [])..add(at);
    if (hits.length < codeAgreement || at.difference(hits.first) < codeSettle) return false;
    _codeHits.remove(code);
    _deliveredCodes[code] = at;
    return true;
  }

  TagPriceRead? _registerPrice(LiveFrame frame, PriceOffer retail, String? code) {
    final at = frame.at;
    final cents = retail.price.cents;
    final delivered = _deliveredPrices[cents];
    if (delivered != null) {
      if (!_sameTag(delivered.barcode, code)) {
        // Mesmo preço, outra etiqueta: a do lado, com outro código.
        _deliveredPrices.remove(cents);
      } else {
        _deliveredPrices[cents] = _Delivered(lastSeen: at, barcode: delivered.barcode ?? code);
        return null;
      }
    }
    _priceHits.add(_PriceHit(at: at, cents: cents, barcode: code));
    final agreeing = _priceHits.where((hit) => hit.cents == cents && _sameTag(hit.barcode, code)).toList();
    if (agreeing.length < tagAgreement) return null;

    _priceHits.removeWhere((hit) => hit.cents == cents);
    final barcode = agreeing.reversed.map((hit) => hit.barcode).nonNulls.firstOrNull;
    _deliveredPrices[cents] = _Delivered(lastSeen: at, barcode: barcode);
    return TagPriceRead(
      price: retail.price,
      barcode: barcode,
      otherOffers: [
        for (final offer in frame.tag.offers)
          if (offer.condition is! AnyCustomer) offer,
      ],
    );
  }

  void _forgetOld(DateTime at) {
    _priceHits.removeWhere((hit) => at.difference(hit.at) > tagWindow);
    _deliveredPrices.removeWhere((_, delivered) => at.difference(delivered.lastSeen) >= release);
    for (final hits in _codeHits.values) {
      hits.removeWhere((hitAt) => at.difference(hitAt) > codeWindow);
    }
    _codeHits.removeWhere((_, hits) => hits.isEmpty);
    _deliveredCodes.removeWhere((_, lastSeen) => at.difference(lastSeen) >= rescanPause);
    _tagCodes.removeWhere((_, lastSeen) => at.difference(lastSeen) >= tagCodeMemory);
  }
}

/// O código nem sempre é lido em todos os quadros: só códigos diferentes
/// separam duas etiquetas.
bool _sameTag(String? a, String? b) => a == null || b == null || a == b;

@immutable
final class _Delivered {
  const _Delivered({required this.lastSeen, this.barcode});

  final DateTime lastSeen;
  final String? barcode;
}

@immutable
final class _PriceHit {
  const _PriceHit({required this.at, required this.cents, this.barcode});

  final DateTime at;
  final int cents;
  final String? barcode;
}
