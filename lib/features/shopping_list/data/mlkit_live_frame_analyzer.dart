import 'dart:async';
import 'dart:ui' show Rect;

import 'package:bipa/core/camera/viewfinder_region.dart';
import 'package:bipa/features/prices/domain/price_tag.dart';
import 'package:bipa/features/prices/domain/price_tag_parser.dart';
import 'package:bipa/features/shopping_list/domain/live_scan.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Lê um quadro da câmera do modo carrinho com o ML Kit: o código de barras e
/// o texto saem do mesmo quadro, e só conta o que está dentro da moldura
/// (ADR 0012). A interpretação do texto continua no [PriceTagParser].
final class MlKitLiveFrameAnalyzer {
  MlKitLiveFrameAnalyzer({PriceTagParser parser = const PriceTagParser()}) : _parser = parser;

  final PriceTagParser _parser;
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final _barcodeScanner = BarcodeScanner(
    formats: [BarcodeFormat.ean13, BarcodeFormat.ean8, BarcodeFormat.upca, BarcodeFormat.upce],
  );

  /// [crop] está nas coordenadas da imagem em pé (ver [viewfinderInImage]);
  /// sem ele, vale o quadro inteiro.
  Future<LiveFrame> analyze(InputImage image, {required DateTime at, PixelRect? crop}) async {
    final (text, barcodes) = await _recognize(image);

    bool inside(Rect box) => crop == null || crop.contains(box.center.dx, box.center.dy);

    final codes = [
      for (final barcode in barcodes)
        if (barcode.rawValue case final value? when inside(barcode.boundingBox)) value,
    ];
    final lines = [
      for (final block in text.blocks)
        for (final line in block.lines)
          if (inside(line.boundingBox))
            OcrLine(
              text: line.text,
              top: line.boundingBox.top,
              height: line.boundingBox.height,
              left: line.boundingBox.left,
              width: line.boundingBox.width,
            ),
    ];
    final tag = lines.isEmpty ? PriceTagReading.empty : _parser.parse(lines, barcodes: codes);
    return LiveFrame(at: at, barcodes: codes, tag: tag);
  }

  /// Os dois reconhecedores rodam juntos. Se um falhar, o erro original sobe
  /// (e não o `ParallelWaitError` do `.wait`), depois de os dois terminarem.
  Future<(RecognizedText, List<Barcode>)> _recognize(InputImage image) async {
    try {
      return await (_textRecognizer.processImage(image), _barcodeScanner.processImage(image)).wait;
    } on ParallelWaitError<(RecognizedText?, List<Barcode>?), (AsyncError?, AsyncError?)> catch (error) {
      final cause = error.errors.$1 ?? error.errors.$2;
      if (cause == null) rethrow;
      Error.throwWithStackTrace(cause.error, cause.stackTrace);
    }
  }

  Future<void> close() async {
    await _textRecognizer.close();
    await _barcodeScanner.close();
  }
}
