import 'package:bipa/core/database/tables.dart';
// Os enums abaixo são usados pelo código gerado (app_database.g.dart).
import 'package:bipa/features/prices/domain/price_condition.dart';
import 'package:bipa/features/prices/domain/price_source.dart';
import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:bipa/features/stock/domain/stock_location.dart';
import 'package:bipa/features/stock/domain/stock_movement_reason.dart';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// Banco local SQLite: a fonte da verdade do app, que funciona 100% offline.
@DriftDatabase(
  tables: [
    Products,
    ProductPackages,
    Markets,
    PriceObservations,
    StockItems,
    StockMovements,
    ShoppingListItems,
    ShoppingTrips,
    CartItems,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Use [executor] em testes, ex.: `AppDatabase(NativeDatabase.memory())`.
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  // v2: produtos ganham photoPath.
  // v3: observações de preço ganham a condição (ADR 0011).
  // v4: lista de compras.
  // v5: modo compra.
  // v6: carrinho da compra.
  // v7: produto e embalagens (ADR 0013).
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      if (from < 2) await migrator.addColumn(products, products.photoPath);
      if (from < 3) {
        await migrator.addColumn(priceObservations, priceObservations.conditionKind);
        await migrator.addColumn(priceObservations, priceObservations.minimumQuantity);
      }
      if (from < 4) await migrator.createTable(shoppingListItems);
      if (from < 5) await migrator.createTable(shoppingTrips);
      if (from < 6) await migrator.createTable(cartItems);
      if (from < 7) await _splitProductsIntoPackages(migrator, hadCart: from >= 6);
    },
    beforeOpen: (details) async {
      // SQLite não aplica chaves estrangeiras sem este pragma.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// v7: cada produto vira um produto e uma embalagem com o mesmo id, que
  /// leva o código, a marca e o tamanho. Os preços antigos apontam para essa
  /// embalagem, e os itens do carrinho também. As chaves estrangeiras ainda
  /// estão desligadas aqui (o pragma é ligado em `beforeOpen`), então recriar
  /// `products` não apaga nada.
  ///
  /// Tudo numa transação: se o app fechar no meio, a próxima abertura refaz
  /// a migração do começo, em vez de encontrar metade dela feita.
  Future<void> _splitProductsIntoPackages(Migrator migrator, {required bool hadCart}) async {
    await transaction(() async {
      await migrator.createTable(productPackages);
      await migrator.createIndex(productPackagesProduct);
      await customStatement(
        'INSERT INTO product_packages '
        '(id, product_id, barcode, brand, size, unit, created_at, updated_at, synced_at) '
        'SELECT id, id, barcode, brand, package_size, unit, created_at, updated_at, NULL FROM products',
      );
      await migrator.addColumn(priceObservations, priceObservations.packageId);
      await migrator.createIndex(priceObservationsPackage);
      await customStatement('UPDATE price_observations SET package_id = product_id');
      // Recria a tabela sem código, marca e tamanho.
      await migrator.alterTable(TableMigration(products));
      // Um carrinho criado agora (de uma versão antes da 6) já nasce no
      // formato novo; o da v6 ganha a embalagem e perde a chave única por
      // produto.
      if (hadCart) {
        await migrator.alterTable(
          TableMigration(
            cartItems,
            newColumns: [cartItems.packageId],
            columnTransformer: {cartItems.packageId: cartItems.productId},
          ),
        );
      }
    });
  }

  static QueryExecutor _openConnection() => driftDatabase(name: 'bipa');
}
