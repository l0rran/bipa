import 'package:bipa/core/money/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Money.tryParse', () {
    final cases = <String, int>{
      '7,99': 799,
      'R\$ 7,99': 799,
      'R\$7,99': 799,
      '7.99': 799,
      '1.234,56': 123456,
      '10': 1000,
      '12,5': 1250,
      ' 0,05 ': 5,
    };

    cases.forEach((input, cents) {
      test('"$input" vira $cents centavos', () {
        expect(Money.tryParse(input), Money.cents(cents));
      });
    });

    for (final input in ['', 'abc', '7,999', '1,2,3', 'R\$']) {
      test('"$input" é inválido', () {
        expect(Money.tryParse(input), isNull);
      });
    }
  });

  group('formatação', () {
    test('format usa o padrão brasileiro com símbolo', () {
      final formatted = const Money.cents(123456).format().replaceAll(' ', ' ');
      expect(formatted, 'R\$ 1.234,56');
    });

    test('formatDecimal não usa símbolo nem separador de milhar', () {
      expect(const Money.cents(123456).formatDecimal(), '1234,56');
      expect(const Money.cents(5).formatDecimal(), '0,05');
      expect(const Money.cents(-150).formatDecimal(), '-1,50');
    });
  });

  test('operações e comparações', () {
    const a = Money.cents(799);
    const b = Money.cents(1000);

    expect(a + b, const Money.cents(1799));
    expect(b - a, const Money.cents(201));
    expect(a * 3, const Money.cents(2397));
    expect(a < b, isTrue);
    expect(b > a, isTrue);
    expect(a.compareTo(b), lessThan(0));
    expect([b, a]..sort(), [a, b]);
    expect(Money.zero.isPositive, isFalse);
  });
}
