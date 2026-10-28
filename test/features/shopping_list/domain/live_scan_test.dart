import 'package:bipa/core/money/money.dart';
import 'package:bipa/features/prices/domain/price_condition.dart';
import 'package:bipa/features/prices/domain/price_tag.dart';
import 'package:bipa/features/shopping_list/domain/live_scan.dart';
import 'package:flutter_test/flutter_test.dart';

const _coffee = '7891000100103';
const _rice = '7891910000197';
final _start = DateTime(2026, 10, 28, 9);

PriceTagReading _tag(int cents, {List<PriceOffer> extra = const []}) {
  final offers = [PriceOffer(price: Money.cents(cents)), ...extra];
  return PriceTagReading(price: Money.cents(cents), offers: offers, candidates: [for (final o in offers) o.price]);
}

/// Um quadro [ms] milissegundos depois do início.
LiveFrame _frame(int ms, {List<String> codes = const [], PriceTagReading tag = PriceTagReading.empty}) =>
    LiveFrame(at: _start.add(Duration(milliseconds: ms)), barcodes: codes, tag: tag);

/// Quadros a cada 300 ms, de [from] até [to].
List<LiveFrame> _frames(int from, int to, {List<String> codes = const [], PriceTagReading? tag}) => [
  for (var ms = from; ms <= to; ms += 300) _frame(ms, codes: codes, tag: tag ?? PriceTagReading.empty),
];

List<LiveScanEvent> _run(LiveScanInterpreter scan, List<LiveFrame> frames) => [for (final f in frames) ...scan.add(f)];

void main() {
  group('etiqueta', () {
    test('o preço vale depois de se repetir em três quadros', () {
      final scan = LiveScanInterpreter();

      expect(scan.add(_frame(0, tag: _tag(2790))), isEmpty);
      expect(scan.add(_frame(300, tag: _tag(2790))), isEmpty);
      expect(scan.add(_frame(600, tag: _tag(2790))), [const TagPriceRead(price: Money.cents(2790))]);
    });

    test('um dígito errado num quadro não conta para o preço certo', () {
      final events = _run(LiveScanInterpreter(), [
        _frame(0, tag: _tag(2790)),
        _frame(300, tag: _tag(2190)),
        _frame(600, tag: _tag(2790)),
      ]);

      expect(events, isEmpty);
    });

    test('quadros espalhados demais no tempo não fazem consenso', () {
      final events = _run(LiveScanInterpreter(), [
        _frame(0, tag: _tag(2790)),
        _frame(1000, tag: _tag(2790)),
        _frame(2000, tag: _tag(2790)),
      ]);

      expect(events, isEmpty);
    });

    test('a mesma etiqueta só vale de novo depois de sair da moldura', () {
      final scan = LiveScanInterpreter();

      expect(_run(scan, _frames(0, 3000, tag: _tag(2790))), hasLength(1));

      // Um segundo e meio sem a etiqueta, e ela volta.
      expect(_run(scan, _frames(4500, 5100, tag: _tag(2790))), [const TagPriceRead(price: Money.cents(2790))]);
    });

    test('a etiqueta do lado, com o mesmo preço e outro código, também vale', () {
      final scan = LiveScanInterpreter();
      _run(scan, _frames(0, 600, codes: [_coffee], tag: _tag(499)));

      final next = _run(scan, _frames(900, 1500, codes: [_rice], tag: _tag(499)));

      expect(next, [const TagPriceRead(price: Money.cents(499), barcode: _rice)]);
    });

    test('a mesma etiqueta, com o código lido só em alguns quadros, vale uma vez', () {
      final scan = LiveScanInterpreter();
      final frames = [
        _frame(0, codes: [_rice], tag: _tag(2790)),
        _frame(300, tag: _tag(2790)),
        _frame(600, codes: [_rice], tag: _tag(2790)),
        _frame(900, tag: _tag(2790)),
        _frame(1200, codes: [_rice], tag: _tag(2790)),
      ];

      expect(_run(scan, frames), [const TagPriceRead(price: Money.cents(2790), barcode: _rice)]);
    });

    test('só preço de clube não vale ao vivo; os outros preços vão junto com o de varejo', () {
      const loyalty = PriceOffer(price: Money.cents(2590), condition: LoyaltyMembers());
      final loyaltyOnly = PriceTagReading(price: loyalty.price, offers: const [loyalty]);

      expect(_run(LiveScanInterpreter(), _frames(0, 900, tag: loyaltyOnly)), isEmpty);

      final events = _run(LiveScanInterpreter(), _frames(0, 600, tag: _tag(2790, extra: const [loyalty])));
      expect(events, [const TagPriceRead(price: Money.cents(2790), otherOffers: [loyalty])]);
    });

    test('etiqueta sem preço escolhido (vários do mesmo tamanho) não vale', () {
      const ambiguous = PriceTagReading(candidates: [Money.cents(399), Money.cents(449)]);

      expect(_run(LiveScanInterpreter(), _frames(0, 900, tag: ambiguous)), isEmpty);
    });
  });

  group('código de barras', () {
    test('bipa quando o código aparece sem preço por um instante', () {
      final scan = LiveScanInterpreter();

      expect(scan.add(_frame(0, codes: [_coffee])), isEmpty);
      expect(scan.add(_frame(300, codes: [_coffee])), isEmpty);
      expect(scan.add(_frame(600, codes: [_coffee])), [const ProductScanned(_coffee)]);
    });

    test('código inválido é ignorado', () {
      expect(_run(LiveScanInterpreter(), _frames(0, 900, codes: ['7891000100104'])), isEmpty);
    });

    test('segurar o produto na frente não bipa de novo; tirar e trazer de volta, sim', () {
      final scan = LiveScanInterpreter();

      expect(_run(scan, _frames(0, 6000, codes: [_coffee])), [const ProductScanned(_coffee)]);
      expect(_run(scan, _frames(9000, 9600, codes: [_coffee])), [const ProductScanned(_coffee)]);
    });

    test('código e preço no mesmo quadro são etiqueta, não unidade bipada', () {
      final events = _run(LiveScanInterpreter(), [
        _frame(0, codes: [_rice]),
        _frame(300, codes: [_rice], tag: _tag(2790)),
        _frame(600, codes: [_rice], tag: _tag(2790)),
        _frame(900, codes: [_rice]),
        _frame(1200, codes: [_rice], tag: _tag(2790)),
      ]);

      expect(events, [const TagPriceRead(price: Money.cents(2790), barcode: _rice)]);
    });

    test('o código da etiqueta lido antes do preço não vira bipe', () {
      final events = _run(LiveScanInterpreter(), [
        _frame(0, codes: [_rice]),
        _frame(250, codes: [_rice]),
        _frame(500, codes: [_rice], tag: _tag(2790)),
        _frame(750, codes: [_rice], tag: _tag(2790)),
        _frame(1000, codes: [_rice], tag: _tag(2790)),
      ]);

      expect(events, [const TagPriceRead(price: Money.cents(2790), barcode: _rice)]);
    });

    test('o código de uma etiqueta volta a bipar depois de um tempo sem a etiqueta', () {
      final scan = LiveScanInterpreter();
      _run(scan, [_frame(0, codes: [_rice], tag: _tag(2790))]);

      expect(_run(scan, [_frame(500, codes: [_rice]), _frame(800, codes: [_rice])]), isEmpty);
      expect(_run(scan, _frames(2500, 3100, codes: [_rice])), [const ProductScanned(_rice)]);
    });
  });

  test('reset esquece o que já foi entregue', () {
    final scan = LiveScanInterpreter();
    _run(scan, _frames(0, 600, codes: [_coffee]));

    scan.reset();

    expect(_run(scan, _frames(900, 1500, codes: [_coffee])), [const ProductScanned(_coffee)]);
  });

  group('ao abrir a câmera', () {
    test('o código que já está na moldura não é bipado, até sair e voltar', () {
      final scan = LiveScanInterpreter()..restart(_start);

      expect(_run(scan, _frames(0, 3000, codes: [_coffee])), isEmpty);
      expect(_run(scan, _frames(6000, 6600, codes: [_coffee])), [const ProductScanned(_coffee)]);
    });

    test('a etiqueta que já está na moldura também não vale', () {
      final scan = LiveScanInterpreter()..restart(_start);

      expect(_run(scan, _frames(0, 3000, tag: _tag(2790))), isEmpty);
    });

    test('o que entra na moldura depois do primeiro segundo vale normalmente', () {
      final scan = LiveScanInterpreter()..restart(_start);

      expect(_run(scan, _frames(1200, 1800, codes: [_coffee])), [const ProductScanned(_coffee)]);
    });
  });
}
