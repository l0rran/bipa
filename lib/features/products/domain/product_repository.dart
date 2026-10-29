import 'package:bipa/core/errors/domain_exception.dart';
import 'package:bipa/features/products/domain/deleted_package.dart';
import 'package:bipa/features/products/domain/moved_package.dart';
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

  /// Apaga o produto e, junto, as embalagens, os preços, o estoque, a lista
  /// e o carrinho dele (ADR 0016), e o arquivo da foto (ADR 0023).
  Future<void> delete(String id);

  /// Junta o produto [fromId] em [intoId], que fica com as embalagens, os
  /// preços, o estoque, a lista e o carrinho dele; [fromId] deixa de existir,
  /// com o arquivo da foto dele.
  /// É o caminho para quem cadastrou o mesmo produto uma vez por marca.
  Future<void> merge({required String fromId, required String intoId});

  /// Passa a embalagem [packageId] para o produto [intoId] (ADR 0022), com
  /// os preços, os lotes em casa, o carrinho e os preços da compra dela. A
  /// quantidade em casa sai do produto antigo e entra no novo. Para o mesmo
  /// produto, não faz nada. Devolve o que foi feito, para o "Desfazer"
  /// (mover de volta e [deleteEmptyStockItem]).
  ///
  /// Lança [PackageNotFoundException] se a embalagem não existir.
  Future<MovedPackage> movePackage({required String packageId, required String intoId});

  /// Tira o item de estoque do produto se ele estiver zerado; com algo em
  /// casa, não faz nada.
  Future<void> deleteEmptyStockItem(String productId);

  /// O produto não tem embalagem, nem preço, nem nada em casa (nem "ter
  /// sempre"): está ali só por engano, e "Apagar produto" resolve.
  Future<bool> isProductEmpty(String productId);

  /// Apaga a embalagem e os preços dela (ADR 0022). O que está em casa e as
  /// compras terminadas ficam sem embalagem. Devolve o que saiu, para
  /// [restorePackage].
  ///
  /// Lança [PackageNotFoundException] se a embalagem não existir e
  /// [PackageInOpenTripException] se ela estiver na compra em andamento.
  Future<DeletedPackage> deletePackage(String packageId);

  /// Grava de volta o que [deletePackage] apagou: o "Desfazer". Sem o
  /// produto (apagado nesse meio-tempo), não faz nada.
  Future<void> restorePackage(DeletedPackage deleted);
}

final class PackageNotFoundException extends DomainException {
  const PackageNotFoundException() : super(DomainErrorCode.packageNotFound);
}

/// A embalagem está no carrinho da compra em andamento: o que está na mão
/// da pessoa não some (ADR 0022).
final class PackageInOpenTripException extends DomainException {
  const PackageInOpenTripException() : super(DomainErrorCode.packageInOpenTrip);
}

final class DuplicateBarcodeException extends DomainException {
  DuplicateBarcodeException({required this.barcode, required this.productName})
    : super(DomainErrorCode.duplicateBarcode, args: [barcode, productName]);

  final String barcode;
  final String productName;
}
