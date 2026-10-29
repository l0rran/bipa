import 'package:bipa/core/errors/domain_exception.dart';
import 'package:bipa/core/id/id_generator.dart';
import 'package:bipa/core/time/clock.dart';
import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:bipa/features/products/domain/package_origin.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/products/domain/product_package.dart';
import 'package:bipa/features/products/domain/product_repository.dart';
import 'package:bipa/features/products/domain/scale_label.dart';
import 'package:meta/meta.dart';

/// O que a pessoa confirmou ao bipar um código novo (ADR 0013).
@immutable
final class NewPackageInput {
  const NewPackageInput({
    required this.unit,
    this.barcode,
    this.productId,
    this.newProductName,
    this.brand,
    this.size,
    this.origin = PackageOrigin.person,
  });

  final String? barcode;

  /// O produto que já existe; sem ele, cria um chamado [newProductName].
  final String? productId;
  final String? newProductName;
  final String? brand;
  final double? size;
  final MeasureUnit unit;

  /// De onde veio o que a folha sugeriu: do catálogo, a embalagem nasce
  /// marcada como cópia dele (ADR 0023, seção 6), mesmo que a pessoa tenha
  /// corrigido algum campo.
  final PackageOrigin origin;
}

/// Caso de uso: cria a embalagem de um código novo, no produto escolhido ou
/// num produto novo.
final class RegisterPackage {
  RegisterPackage({required ProductRepository products, required IdGenerator ids, required Clock clock})
    : _products = products,
      _ids = ids,
      _clock = clock;

  final ProductRepository _products;
  final IdGenerator _ids;
  final Clock _clock;

  Future<(Product, ProductPackage)> call(NewPackageInput input) async {
    final barcode = input.barcode;
    if (barcode != null && ScaleLabel.isScaleCode(barcode)) throw const ScaleBarcodeException();
    // Conferido antes de criar o produto: um código repetido não deixa um
    // produto novo sem embalagem para trás.
    if (barcode != null) {
      final owner = await _products.findPackageByBarcode(barcode);
      if (owner != null) {
        final product = await _products.findById(owner.productId);
        throw DuplicateBarcodeException(barcode: barcode, productName: product?.name ?? barcode);
      }
    }
    final size = input.size;
    if (size != null && size <= 0) throw const InvalidPackageSizeException();

    final now = _clock();
    final Product product;
    if (input.productId case final id?) {
      product = await _products.findById(id) ?? (throw const MissingPackageProductException());
    } else {
      final name = input.newProductName?.trim() ?? '';
      if (name.isEmpty) throw const MissingPackageProductException();
      // O produto conta na grandeza base: uma embalagem de 500 g cria um
      // produto em kg, que soma com as de 1 kg.
      product = Product(id: _ids.newId(), name: name, unit: input.unit.baseUnit, createdAt: now, updatedAt: now);
      await _products.save(product);
    }

    final brand = input.brand?.trim();
    final package = ProductPackage(
      id: _ids.newId(),
      productId: product.id,
      barcode: barcode,
      brand: brand == null || brand.isEmpty ? null : brand,
      size: size,
      unit: input.unit,
      origin: input.origin,
      createdAt: now,
      updatedAt: now,
    );
    await _products.savePackage(package);
    return (product, package);
  }
}

final class MissingPackageProductException extends DomainException {
  const MissingPackageProductException() : super(DomainErrorCode.missingPackageProduct);
}

/// O código da balança muda a cada pesagem e não pode ser de uma embalagem
/// (ADR 0018).
final class ScaleBarcodeException extends DomainException {
  const ScaleBarcodeException() : super(DomainErrorCode.scaleBarcode);
}

final class InvalidPackageSizeException extends DomainException {
  const InvalidPackageSizeException() : super(DomainErrorCode.invalidPackageSize);
}
