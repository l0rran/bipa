import 'package:bipa/core/database/app_database.dart';
import 'package:bipa/core/time/clock.dart';
import 'package:bipa/features/products/data/product_mapper.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/products/domain/product_package.dart';
import 'package:bipa/features/products/domain/product_repository.dart';
import 'package:drift/drift.dart';

final class DriftProductRepository implements ProductRepository {
  const DriftProductRepository(this._db, {Clock clock = systemClock}) : _clock = clock;

  final AppDatabase _db;
  final Clock _clock;

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

  /// Muda o produto em todas as tabelas que o citam, numa transação. Estoque
  /// e lista somam ou deduplicam; o resto só troca de dono. As observações de
  /// preço mantêm a embalagem, que é o que elas de fato registraram.
  @override
  Future<void> merge({required String fromId, required String intoId}) {
    if (fromId == intoId) return Future.value();
    return _db.transaction(() async {
      final now = _clock();
      // `updates` avisa as telas que observam essas tabelas.
      Future<void> move(TableInfo<Table, Object?> table) => _db.customUpdate(
        'UPDATE ${table.actualTableName} SET product_id = ? WHERE product_id = ?',
        variables: [Variable.withString(intoId), Variable.withString(fromId)],
        updates: {table},
      );

      await _db.customUpdate(
        'UPDATE product_packages SET product_id = ?, updated_at = ?, synced_at = NULL WHERE product_id = ?',
        variables: [Variable.withString(intoId), Variable.withDateTime(now), Variable.withString(fromId)],
        updates: {_db.productPackages},
      );
      for (final table in <TableInfo<Table, Object?>>[
        _db.priceObservations,
        _db.cartItems,
        _db.stockMovements,
        _db.stockLots,
      ]) {
        await move(table);
      }

      // Na lista, o item que já existe no destino fica; o outro sai.
      await _db.customUpdate(
        'DELETE FROM shopping_list_items WHERE product_id = ? '
        'AND EXISTS (SELECT 1 FROM shopping_list_items WHERE product_id = ?)',
        variables: [Variable.withString(fromId), Variable.withString(intoId)],
        updates: {_db.shoppingListItems},
        updateKind: UpdateKind.delete,
      );
      await move(_db.shoppingListItems);

      // No estoque, as quantidades somam e vale o maior "ter sempre".
      final from = await (_db.select(_db.stockItems)..where((t) => t.productId.equals(fromId))).getSingleOrNull();
      if (from != null) {
        final into = await (_db.select(_db.stockItems)..where((t) => t.productId.equals(intoId))).getSingleOrNull();
        if (into == null) {
          await move(_db.stockItems);
        } else {
          final fromTarget = from.minimumQuantity;
          final intoTarget = into.minimumQuantity;
          await (_db.update(_db.stockItems)..where((t) => t.productId.equals(intoId))).write(
            StockItemsCompanion(
              quantity: Value(into.quantity + from.quantity),
              minimumQuantity: Value(
                fromTarget == null || (intoTarget != null && intoTarget >= fromTarget) ? intoTarget : fromTarget,
              ),
              updatedAt: Value(now),
            ),
          );
          await (_db.delete(_db.stockItems)..where((t) => t.productId.equals(fromId))).go();
        }
      }
      await (_db.delete(_db.products)..where((t) => t.id.equals(fromId))).go();
    });
  }
}
