import 'package:bipa/core/money/money.dart';
import 'package:bipa/features/prices/domain/price_condition.dart';
import 'package:meta/meta.dart';

/// Linha de texto reconhecida por OCR em uma foto.
@immutable
final class OcrLine {
  const OcrLine({required this.text, required this.top, required this.height, this.left, this.width});

  final String text;

  /// Posição vertical na imagem; define a ordem de leitura.
  final double top;

  /// Altura da linha; em etiquetas, o preço principal costuma ter a maior fonte.
  final double height;

  /// Posição horizontal, quando o OCR informa. Permite juntar os centavos
  /// sobrescritos ao inteiro e saber a que preço um rótulo se refere.
  final double? left;
  final double? width;

  double get bottom => top + height;

  double? get right => switch ((left, width)) {
    (final left?, final width?) => left + width,
    _ => null,
  };
}

/// Um dos preços de uma etiqueta, com a sua condição (ADR 0011).
@immutable
final class PriceOffer {
  const PriceOffer({required this.price, this.condition = const AnyCustomer(), this.regularPrice});

  final Money price;
  final PriceCondition condition;

  /// Preço sem desconto, quando a etiqueta indica promoção ("de/por").
  final Money? regularPrice;

  @override
  bool operator ==(Object other) =>
      other is PriceOffer && other.price == price && other.condition == condition && other.regularPrice == regularPrice;

  @override
  int get hashCode => Object.hash(price, condition, regularPrice);

  @override
  String toString() => 'PriceOffer($price, $condition)';
}

/// Informações extraídas da foto de uma etiqueta de preço.
@immutable
final class PriceTagReading {
  const PriceTagReading({
    this.price,
    this.regularPrice,
    this.barcode,
    this.productNameHint,
    this.candidates = const [],
    this.offers = const [],
    this.perKilo = false,
  });

  static const empty = PriceTagReading();

  /// Preço principal: o da primeira oferta, que é a sem condição quando houver
  /// (o promocional, quando houver "de/por").
  final Money? price;

  /// Preço sem desconto, quando a etiqueta indica promoção.
  final Money? regularPrice;
  final String? barcode;

  /// Sugestão de nome do produto lida da etiqueta.
  final String? productNameHint;

  /// Todos os valores lidos, para o usuário corrigir uma escolha errada.
  final List<Money> candidates;

  /// Um preço por condição (varejo, cartão, atacado), o principal primeiro.
  final List<PriceOffer> offers;

  /// O preço principal é por quilo ("R$ 8,99 KG", "R$ 39,90 /KG"): o
  /// produto é vendido a granel, e quanto custa depende do peso (ADR 0018).
  final bool perKilo;

  bool get isEmpty => price == null && barcode == null;
}

/// Extrai preço, código de barras e nome de uma foto de etiqueta.
abstract interface class PriceTagReader {
  Future<PriceTagReading> read(String imagePath);

  Future<void> close();
}
