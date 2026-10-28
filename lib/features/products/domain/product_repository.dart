import 'package:bipa/core/errors/domain_exception.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/products/domain/product_package.dart';

/// Acesso aos produtos e às suas embalagens (ADR 0013).
abstract interface class ProductRepository {
  /// Produtos ordenados por nome, filtrados pelo nome do produto ou pela
  /// marca ou código de uma das suas embalagens.
  Stream<List<Product>> watchAll({String query = ''});

  Stream<Product?> watchById(String id);

  Future<Product?> findById(String id);

  /// O produto da embalagem com este código.
  Future<Product?> findByBarcode(String barcode);

  /// Cria ou atualiza o produto.
  Future<void> save(Product product);

  /// As embalagens do produto, das mais novas para as mais antigas.
  Stream<List<ProductPackage>> watchPackages(String productId);

  /// As embalagens de vários produtos de uma vez (os da lista, por exemplo).
  Stream<List<ProductPackage>> watchPackagesOfProducts(Set<String> productIds);

  Future<ProductPackage?> findPackageById(String id);

  Future<ProductPackage?> findPackageByBarcode(String barcode);

  /// Cria ou atualiza a embalagem.
  ///
  /// Lança [DuplicateBarcodeException] se o código já pertencer a outra
  /// embalagem.
  Future<void> savePackage(ProductPackage package);

  /// Junta o produto [fromId] em [intoId], que fica com as embalagens, os
  /// preços, o estoque, a lista e o carrinho dele; [fromId] deixa de existir.
  /// É o caminho para quem cadastrou o mesmo produto uma vez por marca.
  Future<void> merge({required String fromId, required String intoId});
}

final class DuplicateBarcodeException extends DomainException {
  DuplicateBarcodeException({required this.barcode, required this.productName})
    : super('O código $barcode já está cadastrado para "$productName".');

  final String barcode;
  final String productName;
}
