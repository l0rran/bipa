import 'package:bipa/features/prices/domain/price_tag.dart';
import 'package:bipa/features/prices/domain/price_tag_parser.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Lê etiquetas com o ML Kit: OCR e código de barras rodam no aparelho,
/// sem internet. A interpretação do texto fica a cargo do [PriceTagParser].
final class MlKitPriceTagReader implements PriceTagReader {
  MlKitPriceTagReader({PriceTagParser parser = const PriceTagParser()}) : _parser = parser;

  final PriceTagParser _parser;
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final _barcodeScanner = BarcodeScanner(
    formats: [BarcodeFormat.ean13, BarcodeFormat.ean8, BarcodeFormat.upca, BarcodeFormat.upce],
  );

  @override
  Future<PriceTagReading> read(String imagePath) async {
    final image = InputImage.fromFilePath(imagePath);
    final text = await _textRecognizer.processImage(image);
    final barcodes = await _barcodeScanner.processImage(image);

    final lines = [
      for (final block in text.blocks)
        for (final line in block.lines)
          OcrLine(
            text: line.text,
            top: line.boundingBox.top,
            height: line.boundingBox.height,
            left: line.boundingBox.left,
            width: line.boundingBox.width,
          ),
    ];
    return _parser.parse(lines, barcodes: barcodes.map((b) => b.rawValue).nonNulls);
  }

  @override
  Future<void> close() async {
    await _textRecognizer.close();
    await _barcodeScanner.close();
  }
}
