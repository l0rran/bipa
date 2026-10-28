import 'dart:io';

import 'package:bipa/features/prices/domain/price_tag.dart';
import 'package:bipa/features/shopping_list/domain/live_scan.dart';
import 'package:bipa/features/shopping_list/presentation/live_camera.dart';

/// O disparo (ADR 0012): fotografa pela própria câmera ao vivo, sem abrir
/// outra tela, e lê a etiqueta da foto. O resultado segue o mesmo caminho
/// da leitura ao vivo. `null` quando a câmera não fotografou ou a foto não
/// tinha um preço que sirva.
Future<TagPriceRead?> photographTag(LiveCameraState camera, PriceTagReader reader) async {
  final path = await camera.takePicture();
  if (path == null) return null;
  try {
    return TagPriceRead.fromPhoto(await reader.read(path));
  } finally {
    // A foto só serviu para ler: não fica no aparelho.
    try {
      await File(path).delete();
    } on FileSystemException {
      // Já foi apagada, ou o sistema a limpa depois.
    }
  }
}
