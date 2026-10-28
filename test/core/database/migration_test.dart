import 'dart:io';

import 'package:bipa/core/database/app_database.dart';
import 'package:bipa/features/prices/domain/price_source.dart';
import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// As migrações mais recentes, num arquivo de verdade: o banco é criado no
/// esquema atual, volta para a versão anterior (tirando a coluna nova com
/// `DROP COLUMN`) e é aberto de novo, o que roda a migração.
///
/// O `DROP COLUMN` exige SQLite 3.35 ou mais novo na máquina que roda os
/// testes (no Windows, a DLL indicada no README).
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

  /// Reabre o banco como se ele estivesse na [version], sem o que veio
  /// depois dela: colunas (`tabela.coluna`) e tabelas inteiras (`tabela`).
  AppDatabase reopenAt(int version, List<String> newer) => AppDatabase(
    NativeDatabase(
      file,
      // Roda antes de o drift olhar a versão, e portanto antes da migração.
      setup: (raw) {
        for (final item in newer) {
          switch (item.split('.')) {
            case [final table, final column]:
              raw.execute('ALTER TABLE $table DROP COLUMN $column');
            case [final table]:
              raw.execute('DROP TABLE $table');
          }
        }
        raw.userVersion = version;
      },
    ),
  );

  /// O que cada versão acrescentou, da 9 em diante.
  const since = {
    9: ['cart_items.price_estimated'],
    10: ['shopping_list_items.quantity'],
    11: ['price_observations.supersedes_id'],
    12: ['scale_items'],
    13: ['trip_prices'],
  };

  /// Tudo o que veio depois da [version].
  List<String> after(int version) => [
    for (final MapEntry(key: added, value: items) in since.entries)
      if (added > version) ...items,
  ];

  test('v9 → v10: os itens que já estavam na lista ficam com quantidade 1', () async {
    final current = AppDatabase(NativeDatabase(file));
    await current
        .into(current.shoppingListItems)
        .insert(ShoppingListItemsCompanion.insert(id: 'pao', name: 'Pão', addedAt: at));
    await current.close();

    final migrated = reopenAt(9, after(9));
    final item = await migrated.select(migrated.shoppingListItems).getSingle();
    await migrated.close();

    expect(item.quantity, 1);
  });

  test('v8 → v10: o carrinho ganha o preço estimado, e a lista, a quantidade', () async {
    final current = AppDatabase(NativeDatabase(file));
    await current
        .into(current.products)
        .insert(
          ProductsCompanion.insert(id: 'cafe', name: 'Café', unit: MeasureUnit.gram, createdAt: at, updatedAt: at),
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
        .insert(
          ShoppingListItemsCompanion.insert(id: 'cafe', productId: const Value('cafe'), name: 'Café', addedAt: at),
        );
    await current.close();

    final migrated = reopenAt(8, after(8));
    final cart = await migrated.select(migrated.cartItems).getSingle();
    final listItem = await migrated.select(migrated.shoppingListItems).getSingle();
    await migrated.close();

    expect((cart.priceCents, cart.priceEstimated), (1899, false));
    expect(listItem.quantity, 1);
  });

  test('v10 → v11: os preços que já estavam não corrigem nenhum outro', () async {
    final current = AppDatabase(NativeDatabase(file));
    await current
        .into(current.products)
        .insert(
          ProductsCompanion.insert(id: 'cafe', name: 'Café', unit: MeasureUnit.gram, createdAt: at, updatedAt: at),
        );
    await current
        .into(current.markets)
        .insert(MarketsCompanion.insert(id: 'vila', name: 'Vila', createdAt: at, updatedAt: at));
    await current
        .into(current.priceObservations)
        .insert(
          PriceObservationsCompanion.insert(
            id: 'p1',
            productId: 'cafe',
            marketId: 'vila',
            priceCents: 1899,
            source: PriceSource.priceTag,
            observedAt: at,
            createdAt: at,
          ),
        );
    await current.close();

    final migrated = reopenAt(10, after(10));
    final price = await migrated.select(migrated.priceObservations).getSingle();
    await migrated.close();

    expect((price.priceCents, price.supersedesId), (1899, null));
  });

  test('v11 → v12: a tabela dos itens da balança é criada vazia', () async {
    // O drift só cria o banco na primeira consulta.
    final current = AppDatabase(NativeDatabase(file));
    await current.select(current.scaleItems).get();
    await current.close();

    final migrated = reopenAt(11, after(11));
    final items = await migrated.select(migrated.scaleItems).get();
    await migrated.close();

    expect(items, isEmpty);
  });

  test('v12 → v13: a tabela dos preços da compra é criada vazia', () async {
    final current = AppDatabase(NativeDatabase(file));
    await current.select(current.tripPrices).get();
    await current.close();

    final migrated = reopenAt(12, after(12));
    final prices = await migrated.select(migrated.tripPrices).get();
    await migrated.close();

    expect(prices, isEmpty);
  });
}
