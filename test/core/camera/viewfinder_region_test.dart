import 'package:bipa/core/camera/viewfinder_region.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('com o sensor deitado, a imagem em pé troca largura e altura', () {
    expect(uprightImageSize(1280, 720, 90), (width: 720.0, height: 1280.0));
    expect(uprightImageSize(1280, 720, 0), (width: 1280.0, height: 720.0));
    expect(uprightImageSize(1280, 720, 270), (width: 720.0, height: 1280.0));
  });

  test('a prévia mais alta que a tela corta em cima e embaixo', () {
    // Tela 360x640 e imagem 720x1600: a escala é 0,5 e a imagem ocupa 800 px
    // de altura; 80 px dela ficam cortados em cima e 80 embaixo.
    final rect = viewfinderInImage(
      viewfinder: const PixelRect(70, 160, 220, 96),
      screenWidth: 360,
      screenHeight: 640,
      imageWidth: 720,
      imageHeight: 1600,
    );

    expect(rect, const PixelRect(140, 480, 440, 192));
  });

  test('a prévia mais larga que a tela corta nas laterais', () {
    // Tela 400x800 e imagem 720x1280: a escala é 0,625 e a imagem ocupa
    // 450 px de largura; 25 px dela ficam cortados de cada lado.
    final rect = viewfinderInImage(
      viewfinder: const PixelRect(25, 100, 200, 100),
      screenWidth: 400,
      screenHeight: 800,
      imageWidth: 720,
      imageHeight: 1280,
    );

    expect(rect, const PixelRect(80, 160, 320, 160));
  });

  test('inflar aumenta cada lado e contains confere o ponto', () {
    const rect = PixelRect(100, 100, 100, 50);

    expect(rect.inflate(0.1), const PixelRect(90, 95, 120, 60));
    expect(rect.contains(150, 125), isTrue);
    expect(rect.contains(95, 125), isFalse);
    expect(rect.inflate(0.1).contains(95, 125), isTrue);
  });
}
