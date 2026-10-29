import 'dart:io';

import 'package:bipa/features/products/data/directory_product_photo_files.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  late Directory photos;
  late DirectoryProductPhotoFiles files;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('bipa_fotos_');
    photos = await Directory('${root.path}${Platform.pathSeparator}fotos').create();
    files = DirectoryProductPhotoFiles(() async => photos);
  });

  tearDown(() => root.delete(recursive: true));

  File at(Directory directory, String name) => File('${directory.path}${Platform.pathSeparator}$name');

  test('apaga a foto pelo caminho relativo à pasta', () async {
    final photo = await at(photos, 'arroz.jpg').writeAsBytes([1]);
    final other = await at(photos, 'feijao.jpg').writeAsBytes([1]);

    await files.delete('arroz.jpg');

    expect(photo.existsSync(), isFalse);
    expect(other.existsSync(), isTrue);
  });

  test('apaga a foto de uma subpasta', () async {
    await Directory('${photos.path}${Platform.pathSeparator}2026').create();
    final photo = await at(photos, '2026${Platform.pathSeparator}arroz.jpg').writeAsBytes([1]);

    await files.delete('2026/arroz.jpg');

    expect(photo.existsSync(), isFalse);
  });

  test('uma foto que não existe não é erro', () async {
    await expectLater(files.delete('sumiu.jpg'), completes);
  });

  test('nada fora da pasta das fotos é apagado', () async {
    final outside = await at(root, 'bipa.sqlite').writeAsBytes([1]);

    for (final path in ['../bipa.sqlite', r'..\bipa.sqlite', '${root.path}/bipa.sqlite', '', '.']) {
      await files.delete(path);
    }

    expect(outside.existsSync(), isTrue);
    expect(photos.existsSync(), isTrue);
  });
}
