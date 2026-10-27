import 'package:bipa/core/database/app_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Instância única do banco local durante a vida do app.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});
