import 'package:bipa/core/money/money.dart';
import 'package:bipa/features/products/domain/gtin.dart';
import 'package:meta/meta.dart';

/// A etiqueta da balança do mercado (ADR 0018): um EAN-13 de circulação
/// restrita, que começa com 2 (GS1 Brasil). Ele traz o código do item na
/// balança daquele mercado e o valor da pesagem, então muda a cada pacote e
/// não identifica um produto no catálogo.
///
/// O formato varia de balança para balança (Toledo, Filizola…), mas o
/// código do item fica nos primeiros dígitos e o valor nos últimos, antes do
/// dígito verificador. Como a maioria imprime o preço total em centavos,
/// [total] é lido assim; a pessoa confere no carrinho.
@immutable
final class ScaleLabel {
  const ScaleLabel({required this.itemKey, required this.total});

  /// Os 7 primeiros dígitos: o prefixo 2 e o código do item, nos formatos de
  /// 4, 5 e 6 dígitos. Igual em toda pesagem do mesmo item no mesmo mercado
  /// (o primeiro dígito do valor só muda acima de R$ 999,99).
  final String itemKey;

  /// Os 5 dígitos antes do verificador, como centavos.
  final Money total;

  /// É um código da balança? Só o EAN-13 válido que começa com 2.
  static bool isScaleCode(String code) => code.length == 13 && code.startsWith('2') && Gtin.isValid(code);

  /// A etiqueta do [code], ou `null` se ele não é da balança.
  static ScaleLabel? tryParse(String code) {
    if (!isScaleCode(code)) return null;
    final cents = int.parse(code.substring(7, 12));
    if (cents == 0) return null;
    return ScaleLabel(itemKey: code.substring(0, 7), total: Money.cents(cents));
  }

  @override
  bool operator ==(Object other) => other is ScaleLabel && other.itemKey == itemKey && other.total == total;

  @override
  int get hashCode => Object.hash(itemKey, total);

  @override
  String toString() => 'ScaleLabel($itemKey, ${total.format()})';
}
