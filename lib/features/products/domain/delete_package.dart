import 'package:bipa/features/products/domain/deleted_package.dart';
import 'package:bipa/features/products/domain/product_repository.dart';

/// Caso de uso: "Apagar embalagem" (ADR 0022), com o "Desfazer".
///
/// Os preços da embalagem saem com ela; o que está em casa fica, sem
/// embalagem. Na compra em andamento não apaga
/// ([PackageInOpenTripException]).
final class DeletePackage {
  DeletePackage({required ProductRepository products}) : _products = products;

  final ProductRepository _products;

  /// Apaga a embalagem e devolve o que saiu, para [undo].
  Future<DeletedPackage> call(String packageId) => _products.deletePackage(packageId);

  /// Grava de volta a embalagem, os preços e as ligações com o estoque e as
  /// compras, com os mesmos ids.
  Future<void> undo(DeletedPackage deleted) => _products.restorePackage(deleted);
}
