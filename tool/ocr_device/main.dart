// Ponto de entrada temporário: roda o leitor de etiquetas de produção nas fotos
// copiadas para <files>/ocr e escreve o resultado no logcat (prefixo OCRBENCH).
import 'dart:io';

import 'package:bipa/features/prices/data/mlkit_price_tag_reader.dart';
import 'package:bipa/features/prices/domain/price_condition.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dir = Directory('${(await getApplicationSupportDirectory()).path}/ocr');
  final files = dir.listSync().whereType<File>().toList()..sort((a, b) => a.path.compareTo(b.path));
  final reader = MlKitPriceTagReader();
  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final out = <String>[];
  void log(String s) {
    out.add(s);
    // ignore: avoid_print
    print('OCRBENCH $s');
  }

  for (final f in files) {
    log('=== ${f.uri.pathSegments.last}');
    final text = await recognizer.processImage(InputImage.fromFilePath(f.path));
    for (final block in text.blocks) {
      for (final line in block.lines) {
        final b = line.boundingBox;
        log('  ocr [${b.left.round()},${b.top.round()} w${b.width.round()} h${b.height.round()}] ${line.text}');
      }
    }
    final r = await reader.read(f.path);
    log(
      '  -> preço=${r.price?.cents} normal=${r.regularPrice?.cents} nome=${r.productNameHint} cod=${r.barcode} candidatos=${r.candidates.map((m) => m.cents).toList()}',
    );
    for (final o in r.offers) {
      final c = switch (o.condition) {
        AnyCustomer() => 'qualquer',
        LoyaltyMembers() => 'cartão',
        Wholesale(:final minimumQuantity) => 'atacado/$minimumQuantity',
      };
      log('     oferta $c: ${o.price.cents} (normal ${o.regularPrice?.cents})');
    }
  }
  log('FIM');
  runApp(
    MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: ListView(children: [for (final s in out) Text(s, style: const TextStyle(fontSize: 10))]),
        ),
      ),
    ),
  );
}
