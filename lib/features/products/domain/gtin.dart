/// Validação de códigos de barras GTIN (EAN-8, UPC-A, EAN-13 e GTIN-14).
abstract final class Gtin {
  static const validLengths = {8, 12, 13, 14};

  static final _onlyDigits = RegExp(r'^\d+$');
  static final _whitespace = RegExp(r'\s');

  /// Verifica o tamanho e o dígito verificador (módulo 10).
  ///
  /// Leituras de câmera e OCR erram dígitos com frequência; o dígito
  /// verificador permite descartar leituras corrompidas.
  static bool isValid(String code) {
    if (!validLengths.contains(code.length) || !_onlyDigits.hasMatch(code)) {
      return false;
    }

    final digits = code.codeUnits.map((unit) => unit - 0x30).toList();
    final checkDigit = digits.removeLast();

    var sum = 0;
    for (var i = 0; i < digits.length; i++) {
      // Pesos 3 e 1 alternados, começando por 3 no dígito mais à direita.
      final positionFromRight = digits.length - i;
      sum += digits[i] * (positionFromRight.isOdd ? 3 : 1);
    }
    return (10 - sum % 10) % 10 == checkDigit;
  }

  /// Remove espaços e retorna o código se for válido; caso contrário, `null`.
  static String? normalize(String raw) {
    final code = raw.replaceAll(_whitespace, '');
    return isValid(code) ? code : null;
  }
}
