import 'package:intl/intl.dart';
import 'package:meta/meta.dart';

/// Valor monetário em reais, armazenado em centavos.
///
/// Usar inteiros evita os erros de arredondamento de `double`
/// (ex.: `0.1 + 0.2 != 0.3`) em somas e comparações de preços.
@immutable
final class Money implements Comparable<Money> {
  const Money.cents(this.cents);

  static const zero = Money.cents(0);

  final int cents;

  static final _currency = NumberFormat.currency(locale: 'pt_BR', symbol: r'R$');

  static final _pattern = RegExp(r'^(\d{1,3}(?:\.\d{3})+|\d+)(?:[,.](\d{1,2}))?$');

  /// Interpreta valores no formato brasileiro, como digitados pelo usuário
  /// ou lidos por OCR: `"7,99"`, `"R$ 1.234,50"`, `"7.99"`, `"10"`.
  ///
  /// Retorna `null` quando o texto não representa um valor válido.
  static Money? tryParse(String input) {
    final text = input.replaceAll(RegExp(r'R\$|\s'), '');
    final match = _pattern.firstMatch(text);
    if (match == null) return null;

    final reais = int.parse(match.group(1)!.replaceAll('.', ''));
    final centavos = int.parse((match.group(2) ?? '0').padRight(2, '0'));
    return Money.cents(reais * 100 + centavos);
  }

  bool get isPositive => cents > 0;

  /// Valor formatado com símbolo, ex.: `R$ 7,99`.
  String format() => _currency.format(cents / 100);

  /// Valor sem símbolo e sem separador de milhar, ex.: `1234,50`.
  /// Útil para preencher campos de texto editáveis.
  String formatDecimal() {
    final absolute = cents.abs();
    final sign = cents < 0 ? '-' : '';
    return '$sign${absolute ~/ 100},${(absolute % 100).toString().padLeft(2, '0')}';
  }

  Money operator +(Money other) => Money.cents(cents + other.cents);

  Money operator -(Money other) => Money.cents(cents - other.cents);

  bool operator <(Money other) => cents < other.cents;

  bool operator <=(Money other) => cents <= other.cents;

  bool operator >(Money other) => cents > other.cents;

  bool operator >=(Money other) => cents >= other.cents;

  @override
  int compareTo(Money other) => cents.compareTo(other.cents);

  @override
  bool operator ==(Object other) => other is Money && other.cents == cents;

  @override
  int get hashCode => cents.hashCode;

  @override
  String toString() => 'Money(${formatDecimal()})';
}
