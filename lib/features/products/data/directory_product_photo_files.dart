import 'dart:io';

import 'package:bipa/features/products/domain/product_photo_files.dart';
import 'package:path_provider/path_provider.dart';

/// A pasta das fotos dos produtos: `fotos/`, nos documentos do app (ADR 0010).
Future<Directory> productPhotosDirectory() async {
  final documents = await getApplicationDocumentsDirectory();
  return Directory('${documents.path}${Platform.pathSeparator}fotos');
}

/// As fotos numa pasta do aparelho; no app, [productPhotosDirectory].
final class DirectoryProductPhotoFiles implements ProductPhotoFiles {
  DirectoryProductPhotoFiles(this._directory);

  final Future<Directory> Function() _directory;

  @override
  Future<void> delete(String photoPath) async {
    // O caminho é relativo à pasta das fotos: nada fora dela é apagado.
    final segments = photoPath.split(RegExp(r'[/\\]'));
    if (photoPath.isEmpty || segments.any((s) => s.isEmpty || s == '.' || s == '..')) return;
    final directory = await _directory();
    final file = File([directory.path, ...segments].join(Platform.pathSeparator));
    try {
      await file.delete();
    } on FileSystemException {
      // Já não existia, ou o sistema não deixou: a foto vira órfã, e o
      // backup leva só as fotos que algum produto cita (ADR 0023).
    }
  }
}
