import 'package:bipa/core/money/money.dart';
import 'package:bipa/features/products/domain/scale_label.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lê o código do item e o total da etiqueta da balança', () {
    expect(ScaleLabel.tryParse('2001230008437'), const ScaleLabel(itemKey: '2001230', total: Money.cents(843)));
  });

  test('outra pesagem do mesmo item tem o mesmo código e outro total', () {
    final first = ScaleLabel.tryParse('2001230008437')!;
    final second = ScaleLabel.tryParse('2001230012991')!;

    expect(second.itemKey, first.itemKey);
    expect(second.total, const Money.cents(1299));
  });

  test('código de produto, dígito errado ou valor zerado não são da balança', () {
    expect(ScaleLabel.tryParse('7891000100103'), isNull);
    expect(ScaleLabel.tryParse('2001230008438'), isNull);
    expect(ScaleLabel.tryParse('2001230000004'), isNull);
    expect(ScaleLabel.isScaleCode('7891000100103'), isFalse);
    expect(ScaleLabel.isScaleCode('2001230008437'), isTrue);
  });
}
