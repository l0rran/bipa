import 'package:bipa/core/formatting/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('quantity remove casas decimais desnecessárias', () {
    expect(Formatters.quantity(2), '2');
    expect(Formatters.quantity(1.5), '1,5');
    expect(Formatters.quantity(0.25), '0,25');
  });

  test('distance usa metros abaixo de 1 km', () {
    expect(Formatters.distance(120.4), '120 m');
    expect(Formatters.distance(1460), '1,5 km');
  });

  test('date usa dia/mês/ano', () {
    expect(Formatters.date(DateTime(2026, 10, 7)), '07/10/2026');
  });
}
