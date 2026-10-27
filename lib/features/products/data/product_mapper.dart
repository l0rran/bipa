import 'package:bipa/core/database/app_database.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:drift/drift.dart';

extension ProductRowMapper on ProductRow {
  Product toEntity() => Product(
    id: id,
    name: name,
    barcode: barcode,
    brand: brand,
    unit: unit,
    packageSize: packageSize,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

extension ProductCompanionMapper on Product {
  /// Toda alteração marca o produto como pendente de sincronização.
  ProductsCompanion toCompanion() => ProductsCompanion.insert(
    id: id,
    name: name,
    barcode: Value(barcode),
    brand: Value(brand),
    unit: unit,
    packageSize: Value(packageSize),
    createdAt: createdAt,
    updatedAt: updatedAt,
    syncedAt: const Value(null),
  );
}
