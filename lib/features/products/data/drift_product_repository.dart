import 'package:bipa/core/database/app_database.dart';
import 'package:bipa/features/products/data/product_mapper.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/products/domain/product_package.dart';
import 'package:bipa/features/products/domain/product_repository.dart';
import 'package:drift/drift.dart';

final class DriftProductRepository implements ProductRepository {
  const DriftProductRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<Product>> watchAll({String query = ''}) {
    final products = _db.products;
    final select = _db.select(products)..orderBy([(t) => OrderingTerm.asc(t.name.lower())]);

    final term = query.trim();
    if (term.isNotEmpty) {
      final pattern = '%$term%';
      final packages = _db.productPackages;
      // Produtos com alguma embalagem da marca ou do código procurado.
      final byPackage = _db.selectOnly(packages)
        ..addColumns([packages.productId])
        ..where(packages.brand.like(pattern) | packages.barcode.equals(term));
      select.where((t) => t.name.like(pattern) | t.id.isInQuery(byPackage));
    }

    return select.watch().map((rows) => [for (final row in rows) row.toEntity()]);
  }

  @override
  Stream<Product?> watchById(String id) {
    final select = _db.select(_db.products)..where((t) => t.id.equals(id));
    return select.watchSingleOrNull().map((row) => row?.toEntity());
  }

  @override
  Future<Product?> findById(String id) async {
    final select = _db.select(_db.products)..where((t) => t.id.equals(id));
    return (await select.getSingleOrNull())?.toEntity();
  }

  @override
  Future<Product?> findByBarcode(String barcode) async {
    final package = await findPackageByBarcode(barcode);
    return package == null ? null : findById(package.productId);
  }

  @override
  Future<void> save(Product product) async {
    await _db.into(_db.products).insertOnConflictUpdate(product.toCompanion());
  }

  @override
  Stream<List<ProductPackage>> watchPackages(String productId) {
    final select = _db.select(_db.productPackages)
      ..where((t) => t.productId.equals(productId))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt), (t) => OrderingTerm.asc(t.id)]);
    return select.watch().map((rows) => [for (final row in rows) row.toEntity()]);
  }

  @override
  Future<ProductPackage?> findPackageById(String id) async {
    final select = _db.select(_db.productPackages)..where((t) => t.id.equals(id));
    return (await select.getSingleOrNull())?.toEntity();
  }

  @override
  Future<ProductPackage?> findPackageByBarcode(String barcode) async {
    final select = _db.select(_db.productPackages)..where((t) => t.barcode.equals(barcode));
    return (await select.getSingleOrNull())?.toEntity();
  }

  @override
  Future<void> savePackage(ProductPackage package) {
    return _db.transaction(() async {
      final barcode = package.barcode;
      if (barcode != null) {
        final owner = await findPackageByBarcode(barcode);
        if (owner != null && owner.id != package.id) {
          final product = await findById(owner.productId);
          throw DuplicateBarcodeException(barcode: barcode, productName: product?.name ?? barcode);
        }
      }
      await _db.into(_db.productPackages).insertOnConflictUpdate(package.toCompanion());
    });
  }
}
