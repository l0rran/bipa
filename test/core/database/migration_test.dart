import 'dart:io';

import 'package:bipa/core/database/app_database.dart';
import 'package:bipa/features/prices/domain/price_condition.dart';
import 'package:bipa/features/prices/domain/price_source.dart';
import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:bipa/features/stock/domain/stock_location.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'schemas/schema.dart';

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
    14: ['remembered_locations'],
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

  test('v13 → v14: os locais lembrados começam vazios, e o que está em casa fica onde está', () async {
    final current = AppDatabase(NativeDatabase(file));
    await current
        .into(current.products)
        .insert(
          ProductsCompanion.insert(id: 'atum', name: 'Atum', unit: MeasureUnit.unit, createdAt: at, updatedAt: at),
        );
    await current
        .into(current.stockItems)
        .insert(
          StockItemsCompanion.insert(productId: 'atum', quantity: 2, location: StockLocation.pantry, updatedAt: at),
        );
    await current.close();

    final migrated = reopenAt(13, after(13));
    final remembered = await migrated.select(migrated.rememberedLocations).get();
    final item = await migrated.select(migrated.stockItems).getSingle();
    await migrated.close();

    expect(remembered, isEmpty);
    expect((item.quantity, item.location), (2, StockLocation.pantry));
  });

  /// Do esquema 14 em diante, cada versão tem o esquema real guardado em
  /// `drift_schemas/` (ADR 0023, lacuna B3), e um backup de qualquer uma delas
  /// precisa abrir no app atual. Os testes acima simulam as versões antigas;
  /// estes partem do esquema que o app de fato criou.
  group('esquema real de cada versão (drift_schemas/)', () {
    final verifier = SchemaVerifier(GeneratedHelper());

    test('o esquema que o app cria é o guardado para a versão atual', () async {
      // Falha quando as tabelas mudam sem subir o `schemaVersion` ou sem
      // guardar o esquema novo (docs/contribuindo.md).
      final current = AppDatabase(NativeDatabase.memory());
      addTearDown(current.close);

      expect(GeneratedHelper.versions.last, current.schemaVersion);
      await verifier.migrateAndValidate(current, current.schemaVersion);
    });

    for (final version in GeneratedHelper.versions) {
      test('v$version → atual: a migração chega ao esquema atual', () async {
        final db = AppDatabase(await verifier.startAt(version));
        addTearDown(db.close);

        await verifier.migrateAndValidate(db, db.schemaVersion);
      });
    }

    test('v14 → atual: os dados gravados no esquema 14 continuam legíveis', () async {
      final schema = await verifier.schemaAt(14);
      addTearDown(schema.close);
      // Datas em segundos, como o drift grava (ADR 0023, seção 3).
      final seconds = at.millisecondsSinceEpoch ~/ 1000;
      schema.rawDatabase
        ..execute(
          'INSERT INTO products (id, name, unit, photo_path, created_at, updated_at) '
          "VALUES ('atum', 'Atum', 'unit', 'atum.jpg', $seconds, $seconds)",
        )
        ..execute(
          'INSERT INTO product_packages (id, product_id, barcode, size, unit, created_at, updated_at) '
          "VALUES ('gomes', 'atum', '7891167021013', 170, 'gram', $seconds, $seconds)",
        )
        ..execute(
          'INSERT INTO markets (id, name, created_at, updated_at) '
          "VALUES ('vila', 'Vila', $seconds, $seconds)",
        )
        ..execute(
          'INSERT INTO price_observations '
          '(id, product_id, market_id, package_id, price_cents, condition_kind, source, observed_at, created_at) '
          "VALUES ('p1', 'atum', 'vila', 'gomes', 899, 'loyaltyMembers', 'priceTag', $seconds, $seconds)",
        )
        ..execute(
          'INSERT INTO stock_items (product_id, quantity, location, updated_at) '
          "VALUES ('atum', 2, 'pantry', $seconds)",
        );

      final db = AppDatabase(schema.newConnection());
      addTearDown(db.close);
      final product = await db.select(db.products).getSingle();
      final package = await db.select(db.productPackages).getSingle();
      final price = await db.select(db.priceObservations).getSingle();
      final item = await db.select(db.stockItems).getSingle();

      expect((product.unit, product.photoPath, product.createdAt), (MeasureUnit.unit, 'atum.jpg', at));
      expect((package.barcode, package.unit), ('7891167021013', MeasureUnit.gram));
      expect(
        (price.priceCents, price.conditionKind, price.source, price.syncedAt),
        (899, PriceConditionKind.loyaltyMembers, PriceSource.priceTag, null),
      );
      expect((item.quantity, item.location), (2, StockLocation.pantry));
    });
  });
}
