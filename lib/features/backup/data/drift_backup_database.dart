import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:bipa/core/database/app_database.dart';
import 'package:bipa/features/backup/domain/backup_exception.dart';
import 'package:bipa/features/backup/domain/backup_manifest.dart';
import 'package:bipa/features/backup/domain/backup_ports.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';

/// O banco do app no backup (ADR 0023, seção 5), com o drift.
///
/// A cópia (`VACUUM INTO`) roda no isolate do próprio banco. Ler e conferir
/// a cópia roda num isolate à parte, com um [AppDatabase] aberto só sobre
/// ela, para a interface não travar e para a migração ser a mesma do app.
final class DriftBackupDatabase implements BackupDatabase {
  DriftBackupDatabase(this._db);

  final AppDatabase _db;

  @override
  int get schemaVersion => _db.schemaVersion;

  @override
  Future<void> copyTo(String path) =>
      // O SQLite aceita qualquer expressão de texto no INTO.
      _db.customStatement('VACUUM INTO ?', [path]);

  @override
  Future<BackupContents> describe(String path) => Isolate.run(() => _describe(path));

  @override
  Future<CheckedBackup> check(String path, BackupManifest manifest) {
    final current = schemaVersion;
    return Isolate.run(() => _check(path, manifest, current));
  }

  @override
  Future<BackupSummary> currentSummary() => _summary(_db);

  @override
  Future<bool> isEmpty() async {
    for (final table in _db.allTables) {
      final row = await _db.customSelect('SELECT EXISTS (SELECT 1 FROM "${table.actualTableName}") AS any').getSingle();
      if (row.read<bool>('any')) return false;
    }
    return true;
  }

  static Future<BackupSummary> _summary(AppDatabase db) async {
    final row = await db.customSelect('''
      SELECT
        (SELECT COUNT(*) FROM products) AS products,
        (SELECT COUNT(*) FROM price_observations) AS prices,
        (SELECT COUNT(*) FROM stock_items WHERE quantity > 0) AS at_home
      ''').getSingle();
    return BackupSummary(
      products: row.read<int>('products'),
      prices: row.read<int>('prices'),
      itemsAtHome: row.read<int>('at_home'),
    );
  }

  static Future<BackupContents> _describe(String path) async {
    final db = _open(File(path));
    try {
      final counts = <String, int>{};
      for (final table in db.allTables) {
        counts[table.actualTableName] = await _count(db, table.actualTableName);
      }
      final photos =
          await (db.selectOnly(db.products, distinct: true)
                ..addColumns([db.products.photoPath])
                ..where(db.products.photoPath.isNotNull()))
              .map((row) => row.read(db.products.photoPath)!)
              .get();
      return BackupContents(counts: counts, summary: await _summary(db), photoPaths: photos.toSet());
    } finally {
      await db.close();
    }
  }

  static Future<CheckedBackup> _check(String path, BackupManifest manifest, int currentSchema) async {
    final file = File(path);
    final version = _userVersion(file);
    if (version > currentSchema) throw BackupException.fromNewerApp('user_version $version');
    if (version != manifest.schemaVersion) {
      throw BackupException.damaged('user_version $version, manifesto ${manifest.schemaVersion}');
    }

    // Antes da migração, com o arquivo como veio: a integridade e as
    // contagens do manifesto.
    String? problem;
    final db = _open(
      file,
      setup: (raw) {
        final integrity = [for (final row in raw.select('PRAGMA integrity_check')) row.columnAt(0)];
        if (integrity.length != 1 || integrity.single != 'ok') {
          problem = 'integrity_check: ${integrity.take(3).join('; ')}';
          throw StateError(problem!);
        }
        for (final MapEntry(key: table, value: expected) in manifest.counts.entries) {
          final Object? count;
          try {
            count = raw.select('SELECT COUNT(*) FROM "$table"').single.columnAt(0);
          } on Exception {
            problem = 'falta a tabela $table';
            rethrow;
          }
          if (count != expected) {
            problem = '$table tem $count linhas, manifesto $expected';
            throw StateError(problem!);
          }
        }
      },
    );
    try {
      try {
        // Abre: roda o `setup` acima e a migração até o esquema atual.
        await db.customSelect('SELECT 1').get();
      } on Object catch (error) {
        throw BackupException.damaged(problem ?? 'não abriu: $error');
      }

      final foreignKeys = await db.customSelect('PRAGMA foreign_key_check').get();
      if (foreignKeys.isNotEmpty) throw BackupException.damaged('foreign_key_check: ${foreignKeys.length}');

      // Cada linha precisa virar o que o app usa. Um nome de enum (ou chave
      // de JSON) que este app não conhece foi gravado por um app mais novo
      // com o mesmo esquema (ADR 0023, lacuna B4).
      for (final table in db.allTables) {
        try {
          await db.select(table).get();
        } on ArgumentError catch (error) {
          throw BackupException.fromNewerApp('${table.actualTableName}: $error');
        } on FormatException catch (error) {
          throw BackupException.fromNewerApp('${table.actualTableName}: $error');
        }
      }
      // Depois da leitura: um backup recusado não chega a ser mexido.
      final adjusted = await _matchLots(db);
      return CheckedBackup(summary: await _summary(db), adjustedItems: adjusted);
    } finally {
      await db.close();
    }
  }

  /// A soma dos lotes é a quantidade de cada item em casa (ADR 0013). Num
  /// backup em que ela não bate, os lotes valem: a quantidade do item passa
  /// a ser a soma deles (zero, se não há lote), e um produto com lotes e sem
  /// item ganha o item, na despensa. O backup não é recusado, porque a
  /// diferença tem conserto e o resto dos dados está bom (decisão do
  /// mantenedor em 29/10, ADR 0023, seção 5). Muda só a cópia em conferência
  /// e devolve quantos itens mudaram.
  static Future<int> _matchLots(AppDatabase db) => db.transaction(() async {
    final missing = await db.customSelect('''
      SELECT COUNT(DISTINCT product_id) AS n FROM stock_lots
      WHERE product_id NOT IN (SELECT product_id FROM stock_items)
      ''').getSingle();
    await db.customStatement('''
      INSERT INTO stock_items (product_id, quantity, location, updated_at)
      SELECT product_id, SUM(quantity), 'pantry', MAX(since) FROM stock_lots
      WHERE product_id NOT IN (SELECT product_id FROM stock_items)
      GROUP BY product_id
      ''');
    const lotSum =
        '(SELECT COALESCE(SUM(lot.quantity), 0.0) FROM stock_lots lot '
        'WHERE lot.product_id = stock_items.product_id)';
    final changed = await db.customUpdate(
      'UPDATE stock_items SET quantity = $lotSum WHERE ABS(quantity - $lotSum) > 0.000001',
      updates: {db.stockItems},
    );
    return missing.read<int>('n') + changed;
  });

  static AppDatabase _open(File file, {DatabaseSetup? setup}) {
    // Neste isolate, o banco do app não está aberto: o aviso de dois bancos
    // não se aplica.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    return AppDatabase(NativeDatabase(file, setup: setup));
  }

  static Future<int> _count(AppDatabase db, String table) async =>
      (await db.customSelect('SELECT COUNT(*) AS n FROM "$table"').getSingle()).read<int>('n');

  /// O `user_version` do cabeçalho do SQLite (bytes 60 a 63), lido sem
  /// abrir o banco: um arquivo que não é SQLite nem chega ao SQLite.
  static int _userVersion(File file) {
    final RandomAccessFile handle;
    try {
      handle = file.openSync();
    } on FileSystemException {
      throw const BackupException.damaged('banco não existe');
    }
    try {
      final header = handle.readSync(100);
      const magic = 'SQLite format 3\u0000';
      if (header.length < 100 || String.fromCharCodes(header.sublist(0, 16)) != magic) {
        throw const BackupException.damaged('não é SQLite');
      }
      return ByteData.sublistView(header).getUint32(60);
    } finally {
      handle.closeSync();
    }
  }
}
