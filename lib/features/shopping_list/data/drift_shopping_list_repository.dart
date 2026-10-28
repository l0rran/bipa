import 'package:bipa/core/database/app_database.dart';
import 'package:bipa/core/id/id_generator.dart';
import 'package:bipa/core/time/clock.dart';
import 'package:bipa/features/products/data/product_mapper.dart';
import 'package:bipa/features/shopping_list/domain/shopping_list_item.dart';
import 'package:bipa/features/shopping_list/domain/shopping_list_repository.dart';
import 'package:drift/drift.dart';

final class DriftShoppingListRepository implements ShoppingListRepository {
  const DriftShoppingListRepository(this._db, {required IdGenerator ids, required Clock clock})
    : _ids = ids,
      _clock = clock;

  final AppDatabase _db;
  final IdGenerator _ids;
  final Clock _clock;

  @override
  Stream<List<ShoppingListEntry>> watchAll() {
    final items = _db.shoppingListItems;
    final products = _db.products;

    final query = _db.select(items).join([
      leftOuterJoin(products, products.id.equalsExp(items.productId)),
    ])..orderBy([OrderingTerm.asc(items.addedAt)]);

    return query.watch().map(
      (rows) => [
        for (final row in rows)
          ShoppingListEntry(
            item: row.readTable(items).toEntity(),
            product: row.readTableOrNull(products)?.toEntity(),
          ),
      ],
    );
  }

  @override
  Future<void> addProduct({required String productId, required String name, int quantity = 1}) {
    final count = _atLeastOne(quantity);
    return _db.transaction(() async {
      final existing = await (_db.select(_db.shoppingListItems)
            ..where((t) => t.productId.equals(productId))
            ..limit(1))
          .getSingleOrNull();
      if (existing == null) {
        await _insert(name: name, productId: productId, quantity: count);
      } else if (existing.checkedAt != null) {
        // Comprado e posto de novo: é outra compra, com a quantidade nova.
        await _write(existing.id, ShoppingListItemsCompanion(checkedAt: const Value(null), quantity: Value(count)));
      }
    });
  }

  @override
  Future<void> addCustom(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return Future.value();
    return _db.transaction(() async {
      // Como no produto: escrever de novo o mesmo item não duplica. A
      // comparação é feita no Dart porque o lower() do SQLite ignora acentos
      // maiúsculos ("PÃO").
      final written = await (_db.select(_db.shoppingListItems)..where((t) => t.productId.isNull())).get();
      final key = trimmed.toLowerCase();
      final existing = written.where((row) => row.name.toLowerCase() == key).firstOrNull;
      if (existing == null) {
        await _insert(name: trimmed);
      } else if (existing.checkedAt != null) {
        await _write(existing.id, const ShoppingListItemsCompanion(checkedAt: Value(null)));
      }
    });
  }

  @override
  Future<void> setChecked(String itemId, {required bool checked}) =>
      _write(itemId, ShoppingListItemsCompanion(checkedAt: Value(checked ? _clock() : null)));

  @override
  Future<void> setQuantity(String itemId, int quantity) =>
      _write(itemId, ShoppingListItemsCompanion(quantity: Value(_atLeastOne(quantity))));

  static int _atLeastOne(int quantity) => quantity < 1 ? 1 : quantity;

  @override
  Future<void> checkProduct(String productId) async {
    await (_db.update(_db.shoppingListItems)
          ..where((t) => t.productId.equals(productId) & t.checkedAt.isNull()))
        .write(ShoppingListItemsCompanion(checkedAt: Value(_clock())));
  }

  @override
  Future<void> uncheckProduct(String productId) async {
    await (_db.update(_db.shoppingListItems)..where((t) => t.productId.equals(productId)))
        .write(const ShoppingListItemsCompanion(checkedAt: Value(null)));
  }

  @override
  Future<void> remove(String itemId) async {
    await (_db.delete(_db.shoppingListItems)..where((t) => t.id.equals(itemId))).go();
  }

  @override
  Future<void> removeProduct(String productId) async {
    await (_db.delete(_db.shoppingListItems)..where((t) => t.productId.equals(productId))).go();
  }

  @override
  Future<void> removeChecked() async {
    await (_db.delete(_db.shoppingListItems)..where((t) => t.checkedAt.isNotNull())).go();
  }

  @override
  Future<void> restore(ShoppingListItem item) => _db.transaction(() async {
    // O produto pode ter voltado à lista antes do "Desfazer": não duplica.
    final productId = item.productId;
    if (productId != null) {
      final back = await (_db.select(_db.shoppingListItems)
            ..where((t) => t.productId.equals(productId))
            ..limit(1))
          .getSingleOrNull();
      if (back != null) return;
    }
    await _db.into(_db.shoppingListItems).insertOnConflictUpdate(
      ShoppingListItemsCompanion.insert(
        id: item.id,
        productId: Value(item.productId),
        name: item.name,
        addedAt: item.addedAt,
        checkedAt: Value(item.checkedAt),
        quantity: Value(item.quantity),
      ),
    );
  });

  Future<void> _insert({required String name, String? productId, int quantity = 1}) async {
    await _db.into(_db.shoppingListItems).insert(
      ShoppingListItemsCompanion.insert(
        id: _ids.newId(),
        productId: Value(productId),
        name: name,
        addedAt: _clock(),
        quantity: Value(quantity),
      ),
    );
  }

  Future<void> _write(String itemId, ShoppingListItemsCompanion changes) async {
    await (_db.update(_db.shoppingListItems)..where((t) => t.id.equals(itemId))).write(changes);
  }
}

extension ShoppingListItemRowMapper on ShoppingListItemRow {
  ShoppingListItem toEntity() => ShoppingListItem(
    id: id,
    productId: productId,
    name: name,
    addedAt: addedAt,
    checkedAt: checkedAt,
    quantity: quantity,
  );
}
