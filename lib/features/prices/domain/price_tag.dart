import 'package:bipa/core/money/money.dart';
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

/// Informações extraídas da foto de uma etiqueta de preço.
@immutable
final class PriceTagReading {
  const PriceTagReading({
    this.price,
    this.regularPrice,
    this.barcode,
    this.productNameHint,
    this.candidates = const [],
  });

  static const empty = PriceTagReading();

  /// Preço principal (o promocional, quando houver "de/por").
  final Money? price;

  /// Preço sem desconto, quando a etiqueta indica promoção.
  final Money? regularPrice;
  final String? barcode;

  /// Sugestão de nome do produto lida da etiqueta.
  final String? productNameHint;

  /// Todos os valores lidos, para o usuário corrigir uma escolha errada.
  final List<Money> candidates;

  bool get isEmpty => price == null && barcode == null;
}

/// Extrai preço, código de barras e nome de uma foto de etiqueta.
abstract interface class PriceTagReader {
  Future<PriceTagReading> read(String imagePath);

  Future<void> close();
}
