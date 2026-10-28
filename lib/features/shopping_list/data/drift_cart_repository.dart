import 'package:bipa/core/database/app_database.dart';
import 'package:bipa/core/id/id_generator.dart';
import 'package:bipa/core/money/money.dart';
import 'package:bipa/core/time/clock.dart';
import 'package:bipa/features/products/data/product_mapper.dart';
import 'package:bipa/features/shopping_list/domain/cart_item.dart';
import 'package:drift/drift.dart';

final class DriftCartRepository implements CartRepository {
  const DriftCartRepository(this._db, {required IdGenerator ids, required Clock clock})
    : _ids = ids,
      _clock = clock;

  final AppDatabase _db;
  final IdGenerator _ids;
  final Clock _clock;

  @override
  Stream<List<CartEntry>> watchTrip(String tripId) {
    final items = _db.cartItems;
    final products = _db.products;

    final query = _db.select(items).join([
      innerJoin(products, products.id.equalsExp(items.productId)),
    ])
      ..where(items.tripId.equals(tripId))
      ..orderBy([OrderingTerm.desc(items.addedAt)]);

    return query.watch().map(
      (rows) => [
        for (final row in rows)
          CartEntry(item: row.readTable(items).toEntity(), product: row.readTable(products).toEntity()),
      ],
    );
  }

  @override
  Future<void> addProduct(String tripId, String productId, {Money? price}) {
    return _db.transaction(() async {
      final existing = await (_db.select(_db.cartItems)
            ..where((t) => t.tripId.equals(tripId) & t.productId.equals(productId)))
          .getSingleOrNull();
      final now = _clock();
      if (existing == null) {
        await _db.into(_db.cartItems).insert(
          CartItemsCompanion.insert(
            id: _ids.newId(),
            tripId: tripId,
            productId: productId,
            priceCents: Value(price?.cents),
            addedAt: now,
          ),
        );
      } else {
        await _write(
          existing.id,
          CartItemsCompanion(
            quantity: Value(existing.quantity + 1),
            priceCents: price == null ? const Value.absent() : Value(price.cents),
            take: const Value(true),
            addedAt: Value(now),
          ),
        );
      }
    });
  }

  @override
  Future<void> setPrice(String itemId, Money price) =>
      _write(itemId, CartItemsCompanion(priceCents: Value(price.cents)));

  @override
  Future<void> setTake(String itemId, {required bool take}) => _write(itemId, CartItemsCompanion(take: Value(take)));

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
      quantity: quantity,
      price: cents == null ? null : Money.cents(cents),
      take: take,
      addedAt: addedAt,
    );
  }
}
