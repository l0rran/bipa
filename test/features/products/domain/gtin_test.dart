import 'package:bipa/features/products/domain/gtin.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Gtin.isValid', () {
    for (final code in [
      '7891910000197', // EAN-13 brasileiro
      '4006381333931', // EAN-13
      '96385074', // EAN-8
      '036000291452', // UPC-A
    ]) {
      test('aceita $code', () => expect(Gtin.isValid(code), isTrue));
    }

    for (final code in [
      '7891910000198', // dígito verificador errado
      '12345', // tamanho inválido
      '789191000019A', // caractere não numérico
      '',
    ]) {
      test('rejeita "$code"', () => expect(Gtin.isValid(code), isFalse));
    }
  });

  test('normalize remove espaços e valida', () {
    expect(Gtin.normalize('7 891910 000197'), '7891910000197');
    expect(Gtin.normalize('7 891910 000198'), isNull);
  });
}
