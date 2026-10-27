import 'package:bipa/core/database/app_database.dart';
import 'package:bipa/features/products/data/product_mapper.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/products/domain/product_repository.dart';
import 'package:drift/drift.dart';

final class DriftProductRepository implements ProductRepository {
  const DriftProductRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<Product>> watchAll({String query = ''}) {
    final select = _db.select(_db.products)
      ..orderBy([(t) => OrderingTerm.asc(t.name.lower())]);

    final term = query.trim();
    if (term.isNotEmpty) {
      final pattern = '%$term%';
      select.where(
        (t) => t.name.like(pattern) | t.brand.like(pattern) | t.barcode.equals(term),
      );
    }

    return select.watch().map(
      (rows) => [for (final row in rows) row.toEntity()],
    );
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
    final select = _db.select(_db.products)..where((t) => t.barcode.equals(barcode));
    return (await select.getSingleOrNull())?.toEntity();
  }

  @override
  Future<void> save(Product product) {
    return _db.transaction(() async {
      final barcode = product.barcode;
      if (barcode != null) {
        final owner = await findByBarcode(barcode);
        if (owner != null && owner.id != product.id) {
          throw DuplicateBarcodeException(barcode: barcode, productName: owner.name);
        }
      }
      await _db.into(_db.products).insertOnConflictUpdate(product.toCompanion());
    });
  }
}
