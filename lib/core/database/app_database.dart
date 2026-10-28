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
  tables: [Products, Markets, PriceObservations, StockItems, StockMovements, ShoppingListItems, ShoppingTrips],
)
class AppDatabase extends _$AppDatabase {
  /// Use [executor] em testes, ex.: `AppDatabase(NativeDatabase.memory())`.
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  // v2: produtos ganham photoPath.
  // v3: observações de preço ganham a condição (ADR 0011).
  // v4: lista de compras.
  // v5: modo compra.
  int get schemaVersion => 5;

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
    },
    beforeOpen: (details) async {
      // SQLite não aplica chaves estrangeiras sem este pragma.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  static QueryExecutor _openConnection() => driftDatabase(name: 'bipa');
}
