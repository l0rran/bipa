import 'dart:io';

import 'package:bipa/core/database/app_database.dart';
import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// As migrações mais recentes, num arquivo de verdade: o banco é criado no
/// esquema atual, volta para a versão anterior (tirando a coluna nova com
/// `DROP COLUMN`, do SQLite 3.35 em diante) e é aberto de novo, o que roda a
/// migração.
void main() {
  late Directory dir;
  late File file;
  final at = DateTime(2026, 10, 28, 9);

  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    dir = await Directory.systemTemp.createTemp('bipa_migration');
    file = File('${dir.path}/bipa.sqlite');
  });

  tearDown(() => dir.delete(recursive: true));

  /// Reabre o banco como se ele estivesse na [version], sem as [columns]
  /// (`tabela.coluna`) que vieram depois dela.
  AppDatabase reopenAt(int version, List<String> columns) => AppDatabase(
    NativeDatabase(
      file,
      // Roda antes de o drift olhar a versão, e portanto antes da migração.
      setup: (raw) {
        for (final column in columns) {
          final [table, name] = column.split('.');
          raw.execute('ALTER TABLE $table DROP COLUMN $name');
        }
        raw.userVersion = version;
      },
    ),
  );

  test('v9 → v10: os itens que já estavam na lista ficam com quantidade 1', () async {
    final current = AppDatabase(NativeDatabase(file));
    await current
        .into(current.shoppingListItems)
        .insert(ShoppingListItemsCompanion.insert(id: 'pao', name: 'Pão', addedAt: at));
    await current.close();

    final migrated = reopenAt(9, ['shopping_list_items.quantity']);
    final item = await migrated.select(migrated.shoppingListItems).getSingle();
    await migrated.close();

    expect(item.quantity, 1);
  });

  test('v8 → v10: o carrinho ganha o preço estimado, e a lista, a quantidade', () async {
    final current = AppDatabase(NativeDatabase(file));
    await current
        .into(current.products)
        .insert(
          ProductsCompanion.insert(
            id: 'cafe',
            name: 'Café',
            unit: MeasureUnit.gram,
            createdAt: at,
            updatedAt: at,
          ),
        );
    await current.into(current.shoppingTrips).insert(ShoppingTripsCompanion.insert(id: 'compra', startedAt: at));
    await current
        .into(current.cartItems)
        .insert(
          CartItemsCompanion.insert(
            id: 'item',
            tripId: 'compra',
            productId: 'cafe',
            priceCents: const Value(1899),
            addedAt: at,
          ),
        );
    await current
        .into(current.shoppingListItems)
        .insert(ShoppingListItemsCompanion.insert(id: 'cafe', productId: const Value('cafe'), name: 'Café', addedAt: at));
    await current.close();

    final migrated = reopenAt(8, ['cart_items.price_estimated', 'shopping_list_items.quantity']);
    final cart = await migrated.select(migrated.cartItems).getSingle();
    final listItem = await migrated.select(migrated.shoppingListItems).getSingle();
    await migrated.close();

    expect((cart.priceCents, cart.priceEstimated), (1899, false));
    expect(listItem.quantity, 1);
  });
}
