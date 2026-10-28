import 'package:bipa/core/database/app_database.dart';
import 'package:bipa/core/database/drift_unit_of_work.dart';
import 'package:bipa/core/transactions/unit_of_work.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Instância única do banco local durante a vida do app.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

/// Junta as operações de um caso de uso numa transação só.
final unitOfWorkProvider = Provider<UnitOfWork>((ref) => DriftUnitOfWork(ref.watch(appDatabaseProvider)));
