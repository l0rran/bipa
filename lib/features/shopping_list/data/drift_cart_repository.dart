import 'package:bipa/core/database/app_database.dart';
import 'package:bipa/core/id/id_generator.dart';
import 'package:bipa/core/money/money.dart';
import 'package:bipa/core/time/clock.dart';
import 'package:bipa/features/products/data/product_mapper.dart';
import 'package:bipa/features/shopping_list/domain/cart_item.dart';
import 'package:drift/drift.dart';

final class DriftCartRepository implements CartRepository {
  const DriftCartRepository(this._db, {required IdGenerator ids, required Clock clock}) : _ids = ids, _clock = clock;

  final AppDatabase _db;
  final IdGenerator _ids;
  final Clock _clock;

  @override
  Stream<List<CartEntry>> watchTrip(String tripId) {
    final items = _db.cartItems;
    final products = _db.products;
    final packages = _db.productPackages;

    final query =
        _db.select(items).join([
            innerJoin(products, products.id.equalsExp(items.productId)),
            leftOuterJoin(packages, packages.id.equalsExp(items.packageId)),
          ])
          ..where(items.tripId.equals(tripId))
          ..orderBy([OrderingTerm.desc(items.addedAt), OrderingTerm.asc(items.id)]);

    return query.watch().map(
      (rows) => [
        for (final row in rows)
          CartEntry(
            item: row.readTable(items).toEntity(),
            product: row.readTable(products).toEntity(),
            package: row.readTableOrNull(packages)?.toEntity(),
          ),
      ],
    );
  }

  @override
  Future<void> addProduct(String tripId, String productId, {String? packageId, Money? price, bool estimated = false}) {
    return _db.transaction(() async {
      final existing = await _selectItem(tripId, productId, packageId).getSingleOrNull();
      final now = _clock();
      if (existing == null) {
        await _db
            .into(_db.cartItems)
            .insert(
              CartItemsCompanion.insert(
                id: _ids.newId(),
                tripId: tripId,
                productId: productId,
                packageId: Value(packageId),
                priceCents: Value(price?.cents),
                priceEstimated: Value(price != null && estimated),
                addedAt: now,
              ),
            );
      } else {
        // Uma estimativa não apaga o preço lido ou digitado nesta compra.
        final keepPrice = price == null || (estimated && existing.priceCents != null && !existing.priceEstimated);
        await _write(
          existing.id,
          CartItemsCompanion(
            quantity: Value(existing.quantity + 1),
            priceCents: keepPrice ? const Value.absent() : Value(price.cents),
            priceEstimated: keepPrice ? const Value.absent() : Value(estimated),
            take: const Value(true),
            addedAt: Value(now),
          ),
        );
      }
    });
  }

  @override
  Future<void> setPrice(String itemId, Money price) =>
      _write(itemId, CartItemsCompanion(priceCents: Value(price.cents), priceEstimated: const Value(false)));

  @override
  Future<void> setQuantity(String itemId, int quantity) =>
      _write(itemId, CartItemsCompanion(quantity: Value(quantity < 1 ? 1 : quantity)));

  @override
  Future<void> setPriceForProduct(String tripId, String productId, Money price, {String? packageId}) {
    return _db.transaction(() async {
      final existing = await _selectItem(tripId, productId, packageId).getSingleOrNull();
      if (existing == null) {
        await _db
            .into(_db.cartItems)
            .insert(
              CartItemsCompanion.insert(
                id: _ids.newId(),
                tripId: tripId,
                productId: productId,
                packageId: Value(packageId),
                priceCents: Value(price.cents),
                addedAt: _clock(),
              ),
            );
      } else {
        await _write(
          existing.id,
          CartItemsCompanion(priceCents: Value(price.cents), priceEstimated: const Value(false)),
        );
      }
    });
  }

  @override
  Future<void> setTake(String itemId, {required bool take}) => _write(itemId, CartItemsCompanion(take: Value(take)));

  @override
  Future<void> setTakeForProduct(String tripId, String productId, {required bool take}) async {
    await (_db.update(_db.cartItems)..where((t) => t.tripId.equals(tripId) & t.productId.equals(productId))).write(
      CartItemsCompanion(take: Value(take)),
    );
  }

  /// O item da embalagem, ou o do produto sem embalagem.
  SimpleSelectStatement<$CartItemsTable, CartItemRow> _selectItem(String tripId, String productId, String? packageId) =>
      _db.select(_db.cartItems)..where(
        (t) =>
            t.tripId.equals(tripId) &
            t.productId.equals(productId) &
            (packageId == null ? t.packageId.isNull() : t.packageId.equals(packageId)),
      );

  Future<void> _write(String itemId, CartItemsCompanion changes) async {
    await (_db.update(_db.cartItems)..where((t) => t.id.equals(itemId))).write(changes);
  }
}

extension CartItemRowMapper on CartItemRow {
  CartItem toEntity() {
    final cents = priceCents;
    return CartItem(
      id: id,
      tripId: tripId,
      productId: productId,
      packageId: packageId,
      quantity: quantity,
      price: cents == null ? null : Money.cents(cents),
      priceEstimated: priceEstimated,
      take: take,
      addedAt: addedAt,
    );
  }
}
