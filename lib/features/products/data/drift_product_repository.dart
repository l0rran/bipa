import 'dart:math' as math;

import 'package:bipa/core/catalog/text_fold.dart';
import 'package:bipa/core/database/app_database.dart';
import 'package:bipa/core/id/id_generator.dart';
import 'package:bipa/core/time/clock.dart';
import 'package:bipa/features/prices/data/drift_price_repository.dart';
import 'package:bipa/features/products/data/product_mapper.dart';
import 'package:bipa/features/products/domain/deleted_package.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/products/domain/product_package.dart';
import 'package:bipa/features/products/domain/product_repository.dart';
import 'package:bipa/features/stock/domain/stock_location.dart';
import 'package:bipa/features/stock/domain/stock_movement_reason.dart';
import 'package:bipa/features/stock/domain/suggested_location.dart';
import 'package:drift/drift.dart';

final class DriftProductRepository implements ProductRepository {
  const DriftProductRepository(this._db, {Clock clock = systemClock, IdGenerator ids = const UuidGenerator()})
    : _clock = clock,
      _ids = ids;

  final AppDatabase _db;
  final Clock _clock;
  final IdGenerator _ids;

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

    // O SQLite ordena os acentos depois do "z" ("Açúcar" depois de "Arroz");
    // a ordem de quem lê é a do alfabeto, sem ligar para acento.
    return select.watch().map((rows) => [for (final row in rows) row.toEntity()]..sort(_byName));
  }

  static int _byName(Product a, Product b) {
    final byFolded = foldText(a.name).compareTo(foldText(b.name));
    return byFolded != 0 ? byFolded : a.id.compareTo(b.id);
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
  Stream<List<ProductPackage>> watchPackagesOfProducts(Set<String> productIds) {
    if (productIds.isEmpty) return Stream.value(const []);
    final select = _db.select(_db.productPackages)..where((t) => t.productId.isIn(productIds));
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
  Future<void> delete(String id) async {
    // As tabelas filhas apagam em cascata (chaves estrangeiras).
    await (_db.delete(_db.products)..where((t) => t.id.equals(id))).go();
  }

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
      // As observações de preço são imutáveis (ADR 0007), mas o produto delas
      // deixou de existir: mudam de produto e voltam para a fila de
      // sincronização, a exceção registrada no ADR 0013.
      await _db.customUpdate(
        'UPDATE price_observations SET product_id = ?, synced_at = NULL WHERE product_id = ?',
        variables: [Variable.withString(intoId), Variable.withString(fromId)],
        updates: {_db.priceObservations},
      );

      // No carrinho, linhas sem embalagem dos dois produtos na mesma compra
      // viram uma só, somando as quantidades.
      final sameTripWithoutPackage =
          'FROM cart_items other WHERE other.trip_id = cart_items.trip_id '
          'AND other.product_id = ? AND other.package_id IS NULL';
      await _db.customUpdate(
        'UPDATE cart_items SET '
        'quantity = quantity + (SELECT SUM(other.quantity) $sameTripWithoutPackage), '
        'price_cents = COALESCE(price_cents, (SELECT MAX(other.price_cents) $sameTripWithoutPackage)) '
        'WHERE product_id = ? AND package_id IS NULL AND EXISTS (SELECT 1 $sameTripWithoutPackage)',
        variables: [
          for (final id in [fromId, fromId, intoId, fromId]) Variable.withString(id),
        ],
        updates: {_db.cartItems},
      );
      await _db.customUpdate(
        'DELETE FROM cart_items WHERE product_id = ? AND package_id IS NULL '
        'AND EXISTS (SELECT 1 $sameTripWithoutPackage)',
        variables: [Variable.withString(fromId), Variable.withString(intoId)],
        updates: {_db.cartItems},
        updateKind: UpdateKind.delete,
      );

      for (final table in <TableInfo<Table, Object?>>[_db.cartItems, _db.stockMovements, _db.stockLots]) {
        await move(table);
      }

      // Na lista, o item que já existe no destino fica, marcado se um dos
      // dois estava; o outro sai.
      await _db.customUpdate(
        'UPDATE shopping_list_items SET checked_at = '
        '(SELECT MAX(other.checked_at) FROM shopping_list_items other WHERE other.product_id IN (?, ?)) '
        'WHERE product_id = ? AND checked_at IS NULL',
        variables: [Variable.withString(fromId), Variable.withString(intoId), Variable.withString(intoId)],
        updates: {_db.shoppingListItems},
      );
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
      // O local lembrado (ADR 0021) passa se o outro não tiver um; o que
      // sobra sai em cascata com o produto.
      await _db.customUpdate(
        'UPDATE OR IGNORE remembered_locations SET product_id = ? WHERE product_id = ?',
        variables: [Variable.withString(intoId), Variable.withString(fromId)],
        updates: {_db.rememberedLocations},
      );
      await (_db.delete(_db.products)..where((t) => t.id.equals(fromId))).go();
    });
  }

  @override
  Future<void> movePackage({required String packageId, required String intoId}) => _db.transaction(() async {
    final package = await _selectPackage(packageId).getSingleOrNull();
    if (package == null) throw const PackageNotFoundException();
    final fromId = package.productId;
    if (fromId == intoId) return;
    final now = _clock();

    await (_db.update(_db.productPackages)..where((t) => t.id.equals(packageId))).write(
      ProductPackagesCompanion(productId: Value(intoId), updatedAt: Value(now), syncedAt: const Value(null)),
    );
    // A exceção do ADR 0013, agora para uma embalagem só (ADR 0022): as
    // observações dela mudam de produto e voltam para a fila de
    // sincronização. Preço, mercado, data e embalagem não mudam.
    await _db.customUpdate(
      'UPDATE price_observations SET product_id = ?, synced_at = NULL WHERE package_id = ?',
      variables: [Variable.withString(intoId), Variable.withString(packageId)],
      updates: {_db.priceObservations},
    );
    // O carrinho e os preços das compras. A chave do preço da compra começa
    // pelo produto (`produto:embalagem`, `TripPrice.keyOf`).
    await _db.customUpdate(
      'UPDATE cart_items SET product_id = ? WHERE package_id = ?',
      variables: [Variable.withString(intoId), Variable.withString(packageId)],
      updates: {_db.cartItems},
    );
    await _db.customUpdate(
      'UPDATE trip_prices SET product_id = ?, item_key = ? || substr(item_key, length(product_id) + 1) '
      'WHERE package_id = ?',
      variables: [Variable.withString(intoId), Variable.withString(intoId), Variable.withString(packageId)],
      updates: {_db.tripPrices},
    );

    // O que está em casa dessa embalagem passa de um produto para o outro.
    final lots = await (_db.select(_db.stockLots)..where((t) => t.packageId.equals(packageId))).get();
    final moved = lots.fold(0.0, (sum, lot) => sum + lot.quantity);
    await (_db.update(
      _db.stockLots,
    )..where((t) => t.packageId.equals(packageId))).write(StockLotsCompanion(productId: Value(intoId)));
    if (moved <= _epsilon) return;

    final from = await _selectStockItem(fromId).getSingleOrNull();
    if (from != null) {
      final quantity = math.max(0.0, from.quantity - moved);
      await (_db.update(_db.stockItems)..where((t) => t.productId.equals(fromId))).write(
        StockItemsCompanion(quantity: Value(quantity), updatedAt: Value(now)),
      );
      await _recordAdjustment(fromId, quantity - from.quantity, now);
    }
    final into = await _selectStockItem(intoId).getSingleOrNull();
    if (into == null) {
      await _db
          .into(_db.stockItems)
          .insert(
            StockItemsCompanion.insert(
              productId: intoId,
              quantity: moved,
              location: await _newItemLocation(intoId),
              updatedAt: now,
            ),
          );
    } else {
      await (_db.update(_db.stockItems)..where((t) => t.productId.equals(intoId))).write(
        StockItemsCompanion(quantity: Value(into.quantity + moved), updatedAt: Value(now)),
      );
    }
    await _recordAdjustment(intoId, moved, now);
  });

  @override
  Future<DeletedPackage> deletePackage(String packageId) => _db.transaction(() async {
    final row = await _selectPackage(packageId).getSingleOrNull();
    if (row == null) throw const PackageNotFoundException();

    // Na compra em andamento, a embalagem é o que está na mão da pessoa.
    final openTrips = _db.selectOnly(_db.shoppingTrips)
      ..addColumns([_db.shoppingTrips.id])
      ..where(_db.shoppingTrips.finishedAt.isNull());
    final inOpenCart =
        await (_db.select(_db.cartItems)
              ..where((t) => t.packageId.equals(packageId) & t.tripId.isInQuery(openTrips))
              ..limit(1))
            .getSingleOrNull();
    final inOpenPrices =
        await (_db.select(_db.tripPrices)
              ..where((t) => t.packageId.equals(packageId) & t.tripId.isInQuery(openTrips))
              ..limit(1))
            .getSingleOrNull();
    if (inOpenCart != null || inOpenPrices != null) throw const PackageInOpenTripException();

    final prices = await (_db.select(_db.priceObservations)..where((t) => t.packageId.equals(packageId))).get();
    final lots = await (_db.select(_db.stockLots)..where((t) => t.packageId.equals(packageId))).get();
    final cartItems = await (_db.select(_db.cartItems)..where((t) => t.packageId.equals(packageId))).get();

    // Os preços saem explicitamente: com a chave nula, virariam preços do
    // produto sem tamanho (ADR 0022). Lotes e carrinho ficam sem embalagem,
    // pela chave estrangeira.
    await (_db.delete(_db.priceObservations)..where((t) => t.packageId.equals(packageId))).go();
    await (_db.delete(_db.productPackages)..where((t) => t.id.equals(packageId))).go();

    return DeletedPackage(
      package: row.toEntity(),
      prices: [for (final price in prices) price.toEntity()],
      lotIds: {for (final lot in lots) lot.id},
      cartItemIds: {for (final item in cartItems) item.id},
    );
  });

  @override
  Future<void> restorePackage(DeletedPackage deleted) => _db.transaction(() async {
    final package = deleted.package;
    if (await findById(package.productId) == null) return;
    await savePackage(package);
    await _db.batch((batch) {
      batch.insertAll(_db.priceObservations, [
        for (final price in deleted.prices) price.toCompanion(),
      ], mode: InsertMode.insertOrIgnore);
    });

    final lotIds = deleted.lotIds;
    if (lotIds.isNotEmpty) {
      await (_db.update(_db.stockLots)
            ..where((t) => t.id.isIn(lotIds) & t.packageId.isNull() & t.productId.equals(package.productId)))
          .write(StockLotsCompanion(packageId: Value(package.id)));
    }
    final cartItemIds = deleted.cartItemIds;
    if (cartItemIds.isNotEmpty) {
      await (_db.update(_db.cartItems)..where((t) => t.id.isIn(cartItemIds) & t.packageId.isNull())).write(
        CartItemsCompanion(packageId: Value(package.id)),
      );
    }
    // Os preços das compras guardam a embalagem na chave do item.
    await _db.customUpdate(
      "UPDATE trip_prices SET package_id = ? WHERE package_id IS NULL AND item_key = product_id || ':' || ?",
      variables: [Variable.withString(package.id), Variable.withString(package.id)],
      updates: {_db.tripPrices},
    );
  });

  SimpleSelectStatement<$ProductPackagesTable, ProductPackageRow> _selectPackage(String id) =>
      _db.select(_db.productPackages)..where((t) => t.id.equals(id));

  SimpleSelectStatement<$StockItemsTable, StockItemRow> _selectStockItem(String productId) =>
      _db.select(_db.stockItems)..where((t) => t.productId.equals(productId));

  Future<void> _recordAdjustment(String productId, double delta, DateTime now) async {
    if (delta.abs() <= _epsilon) return;
    await _db
        .into(_db.stockMovements)
        .insert(
          StockMovementsCompanion.insert(
            id: _ids.newId(),
            productId: productId,
            delta: delta,
            reason: StockMovementReason.adjustment,
            occurredAt: now,
          ),
        );
  }

  /// O local do item que nasce no produto: o lembrado ou o sugerido pelo
  /// nome, como em `DriftStockRepository` (ADR 0021).
  Future<StockLocation> _newItemLocation(String productId) async {
    final remembered = await (_db.select(
      _db.rememberedLocations,
    )..where((t) => t.productId.equals(productId))).getSingleOrNull();
    if (remembered != null) return remembered.location;
    final product = await findById(productId);
    return product == null ? StockLocation.pantry : suggestedLocation(product.name);
  }
}

const _epsilon = 1e-9;
