import 'package:bipa/core/database/app_database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';

/// Banco em memória, isolado por teste.
///
/// Requer a biblioteca nativa do SQLite na máquina que roda os testes
/// (já presente no macOS e na maioria das distribuições Linux; no Windows,
/// veja o README).
AppDatabase createTestDatabase() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase(NativeDatabase.memory());
}
