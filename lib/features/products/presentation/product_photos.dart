import 'dart:io';

import 'package:bipa/features/products/data/directory_product_photo_files.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Pasta onde ficam as fotos dos produtos, dentro dos documentos do app.
/// Os produtos guardam o caminho relativo a ela ([Product.photoPath]).
final productPhotosDirectoryProvider = FutureProvider<Directory>((ref) => productPhotosDirectory());

/// O arquivo da foto do produto, ou `null` se ele não tem foto (ou se a pasta
/// ainda não foi resolvida). A interface cai no ícone da categoria.
File? productPhotoFile(Product product, Directory? photos) {
  final path = product.photoPath;
  if (path == null || photos == null) return null;
  return File('${photos.path}${Platform.pathSeparator}$path');
}
