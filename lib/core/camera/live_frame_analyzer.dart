import 'package:bipa/core/camera/viewfinder_region.dart';
import 'package:bipa/features/shopping_list/domain/live_scan.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Lê um quadro da câmera: os códigos de barras e a etiqueta, só dentro do
/// recorte (ADR 0012). A implementação com o ML Kit fica em `data`; a tela
/// recebe esta interface pelo provider.
abstract interface class LiveFrameAnalyzer {
  /// [crop] está nas coordenadas da imagem em pé; sem ele, vale o quadro
  /// inteiro.
  Future<LiveFrame> analyze(InputImage image, {required DateTime at, PixelRect? crop});

  Future<void> close();
}
