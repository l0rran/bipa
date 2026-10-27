import 'package:bipa/core/database/tables.dart';
// Os enums abaixo são usados pelo código gerado (app_database.g.dart).
import 'package:bipa/features/prices/domain/price_source.dart';
import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:bipa/features/stock/domain/stock_location.dart';
import 'package:bipa/features/stock/domain/stock_movement_reason.dart';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// Banco local SQLite: a fonte da verdade do app, que funciona 100% offline.
@DriftDatabase(
  tables: [Products, Markets, PriceObservations, StockItems, StockMovements],
)
class AppDatabase extends _$AppDatabase {
  /// Use [executor] em testes, ex.: `AppDatabase(NativeDatabase.memory())`.
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    beforeOpen: (details) async {
      // SQLite não aplica chaves estrangeiras sem este pragma.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  static QueryExecutor _openConnection() => driftDatabase(name: 'bipa');
}
