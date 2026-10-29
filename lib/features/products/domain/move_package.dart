import 'package:bipa/core/id/id_generator.dart';
import 'package:bipa/core/time/clock.dart';
import 'package:bipa/features/prices/domain/register_price_observation.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/products/domain/product_repository.dart';
import 'package:bipa/features/products/domain/register_package.dart';

/// Caso de uso: "Mover para outro produto…" (ADR 0022). Conserta a
/// embalagem posta no produto errado, levando os preços e o que está em
/// casa dela.
final class MovePackage {
  MovePackage({required ProductRepository products, required IdGenerator ids, required Clock clock})
    : _products = products,
      _ids = ids,
      _clock = clock;

  final ProductRepository _products;
  final IdGenerator _ids;
  final Clock _clock;

  /// Move a embalagem para o produto [intoProductId] ou, sem ele, para um
  /// produto novo chamado [newProductName]. Devolve o produto que ficou com
  /// ela; `null` quando ela já era desse produto e nada mudou.
  Future<Product?> call({required String packageId, String? intoProductId, String? newProductName}) async {
    final package = await _products.findPackageById(packageId) ?? (throw const PackageNotFoundException());
    if (intoProductId == package.productId) return null;

    final Product into;
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
    }
    await _products.movePackage(packageId: packageId, intoId: into.id);
    return into;
  }
}
