import 'dart:math' as math;

import 'package:meta/meta.dart';

/// Um retângulo em pixels, sem depender do Flutter: serve tanto para a tela
/// quanto para a imagem da câmera.
@immutable
final class PixelRect {
  const PixelRect(this.left, this.top, this.width, this.height) : assert(width >= 0 && height >= 0);

  final double left;
  final double top;
  final double width;
  final double height;

  double get right => left + width;
  double get bottom => top + height;

  bool contains(double x, double y) => x >= left && x <= right && y >= top && y <= bottom;

  /// O mesmo retângulo, aumentado em [fraction] da largura e da altura de
  /// cada lado.
  PixelRect inflate(double fraction) {
    assert(fraction >= 0);
    final dx = width * fraction;
    final dy = height * fraction;
    return PixelRect(left - dx, top - dy, width + 2 * dx, height + 2 * dy);
  }

  @override
  bool operator ==(Object other) =>
      other is PixelRect && other.left == left && other.top == top && other.width == width && other.height == height;

  @override
  int get hashCode => Object.hash(left, top, width, height);

  @override
  String toString() => 'PixelRect($left, $top, $width, $height)';
}

/// O tamanho da imagem como o reconhecedor a enxerga, já em pé: com o sensor
/// girado 90° ou 270°, largura e altura trocam de lugar.
({double width, double height}) uprightImageSize(double width, double height, int rotationDegrees) =>
    rotationDegrees % 180 == 0 ? (width: width, height: height) : (width: height, height: width);

/// Converte a moldura desenhada na tela para as coordenadas da imagem em pé,
/// com a prévia da câmera preenchendo a tela em `BoxFit.cover` (centralizada
/// e cortada no lado que sobra). É o recorte que a leitura ao vivo usa para
/// ignorar o que está fora da moldura (ADR 0012).
PixelRect viewfinderInImage({
  required PixelRect viewfinder,
  required double screenWidth,
  required double screenHeight,
  required double imageWidth,
  required double imageHeight,
}) {
  final scale = math.max(screenWidth / imageWidth, screenHeight / imageHeight);
  final offsetX = (screenWidth - imageWidth * scale) / 2;
  final offsetY = (screenHeight - imageHeight * scale) / 2;
  return PixelRect(
    (viewfinder.left - offsetX) / scale,
    (viewfinder.top - offsetY) / scale,
    viewfinder.width / scale,
    viewfinder.height / scale,
  );
}
