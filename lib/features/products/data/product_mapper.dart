import 'package:bipa/core/database/app_database.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/products/domain/product_package.dart';
import 'package:drift/drift.dart';

extension ProductRowMapper on ProductRow {
  Product toEntity() => Product(
    id: id,
    name: name,
    unit: unit,
    photoPath: photoPath,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

extension ProductCompanionMapper on Product {
  /// Toda alteração marca o produto como pendente de sincronização.
  ProductsCompanion toCompanion() => ProductsCompanion.insert(
    id: id,
    name: name,
    unit: unit,
    photoPath: Value(photoPath),
    createdAt: createdAt,
    updatedAt: updatedAt,
    syncedAt: const Value(null),
  );
}

extension ProductPackageRowMapper on ProductPackageRow {
  ProductPackage toEntity() => ProductPackage(
    id: id,
    productId: productId,
    barcode: barcode,
    brand: brand,
    size: size,
    unit: unit,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

extension ProductPackageCompanionMapper on ProductPackage {
  /// Toda alteração marca a embalagem como pendente de sincronização.
  ProductPackagesCompanion toCompanion() => ProductPackagesCompanion.insert(
    id: id,
    productId: productId,
    barcode: Value(barcode),
    brand: Value(brand),
    size: Value(size),
    unit: unit,
    createdAt: createdAt,
    updatedAt: updatedAt,
    syncedAt: const Value(null),
  );
}
