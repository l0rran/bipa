import 'package:bipa/core/errors/domain_exception.dart';
import 'package:bipa/features/products/domain/product.dart';

/// Acesso aos produtos cadastrados.
abstract interface class ProductRepository {
  /// Produtos ordenados por nome, filtrados por nome, marca ou código.
  Stream<List<Product>> watchAll({String query = ''});

  Stream<Product?> watchById(String id);

  Future<Product?> findById(String id);

  Future<Product?> findByBarcode(String barcode);

  /// Cria ou atualiza o produto.
  ///
  /// Lança [DuplicateBarcodeException] se o código de barras já pertencer a
  /// outro produto.
  Future<void> save(Product product);
}

final class DuplicateBarcodeException extends DomainException {
  DuplicateBarcodeException({required this.barcode, required this.productName})
    : super('O código $barcode já está cadastrado para "$productName".');

  final String barcode;
  final String productName;
}
