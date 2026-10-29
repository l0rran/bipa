import 'package:bipa/core/id/id_generator.dart';
import 'package:bipa/core/time/clock.dart';
import 'package:bipa/features/prices/domain/register_price_observation.dart';
import 'package:bipa/features/products/domain/moved_package.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/products/domain/product_repository.dart';
import 'package:bipa/features/products/domain/register_package.dart';
import 'package:meta/meta.dart';

/// Caso de uso: "Mover para outro produto…" (ADR 0022). Conserta a
/// embalagem posta no produto errado, levando os preços e o que está em
/// casa dela, e o "Desfazer" dela.
final class MovePackage {
  MovePackage({required ProductRepository products, required IdGenerator ids, required Clock clock})
    : _products = products,
      _ids = ids,
      _clock = clock;

  final ProductRepository _products;
  final IdGenerator _ids;
  final Clock _clock;

  /// Move a embalagem para o produto [intoProductId] ou, sem ele, para um
  /// produto novo chamado [newProductName]. Devolve o que foi feito, para
  /// [undo]; `null` quando ela já era desse produto e nada mudou.
  Future<PackageMove?> call({required String packageId, String? intoProductId, String? newProductName}) async {
    final package = await _products.findPackageById(packageId) ?? (throw const PackageNotFoundException());
    if (intoProductId == package.productId) return null;

    final Product into;
    var createdProduct = false;
    if (intoProductId case final id?) {
      into = await _products.findById(id) ?? (throw ProductNotFoundException(id));
    } else {
      final name = newProductName?.trim() ?? '';
      if (name.isEmpty) throw const MissingPackageProductException();
      final now = _clock();
      // Como no cadastro de um código novo: o produto conta na grandeza base
      // da embalagem.
      into = Product(id: _ids.newId(), name: name, unit: package.unit.baseUnit, createdAt: now, updatedAt: now);
      await _products.save(into);
      createdProduct = true;
    }
    final moved = await _products.movePackage(packageId: packageId, intoId: into.id);
    return PackageMove(
      into: into,
      moved: moved,
      createdProduct: createdProduct,
      sourceEmpty: await _products.isProductEmpty(moved.fromProductId),
    );
  }

  /// O "Desfazer": leva a embalagem de volta para o produto de origem, com o
  /// que veio com ela, e tira o que nasceu só por causa da movida: o item de
  /// estoque zerado do destino e, se a movida o criou, o produto vazio.
  /// Lança [PackageNotFoundException] se a embalagem sumiu nesse meio-tempo.
  Future<void> undo(PackageMove move) async {
    final moved = move.moved;
    await _products.movePackage(packageId: moved.packageId, intoId: moved.fromProductId);
    if (moved.createdStockItem) await _products.deleteEmptyStockItem(moved.intoProductId);
    if (move.createdProduct && await _products.isProductEmpty(moved.intoProductId)) {
      await _products.delete(moved.intoProductId);
    }
  }
}

/// O resultado de [MovePackage.call].
@immutable
final class PackageMove {
  const PackageMove({required this.into, required this.moved, required this.createdProduct, required this.sourceEmpty});

  /// O produto que ficou com a embalagem.
  final Product into;

  final MovedPackage moved;

  /// O produto de destino foi criado pela movida.
  final bool createdProduct;

  /// O produto de origem ficou sem embalagem, sem preço e sem nada em casa:
  /// a tela oferece "Apagar produto".
  final bool sourceEmpty;
}
