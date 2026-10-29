import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

/// Uma linha de `catalog_packages`, com os nomes de coluna do arquivo.
typedef TestCatalogRow = ({
  String barcode,
  String name,
  String? brand,
  String? quantity,
  double? sizeValue,
  String? sizeUnit,
  String? kind,
  String source,
});

TestCatalogRow catalogRow(
  String barcode,
  String name, {
  String? brand,
  String? quantity,
  double? sizeValue,
  String? sizeUnit,
  String? kind,
  String source = 'off',
}) => (
  barcode: barcode,
  name: name,
  brand: brand,
  quantity: quantity,
  sizeValue: sizeValue,
  sizeUnit: sizeUnit,
  kind: kind,
  source: source,
);

/// O aviso de atribuição do catálogo de teste.
const testCatalogAttribution =
    'Contém informações do Open Food Facts, disponíveis sob a ODbL. https://world.openfoodfacts.org';

/// Grava em [file] um catálogo pequeno, no formato fixo do arquivo que
/// `tool/catalogo` gera (ADR 0024): enquanto o arquivo real não chega, os
/// testes usam este.
Future<File> writeTestCatalog(File file, List<TestCatalogRow> rows, {int userVersion = 1}) async {
  final db = _RawDatabase(
    NativeDatabase(
      file,
      enableMigrations: false,
      setup: (raw) {
        raw
          ..execute(
            'CREATE TABLE catalog_packages (barcode TEXT PRIMARY KEY, name TEXT NOT NULL, brand TEXT, '
            'quantity TEXT, size_value REAL, size_unit TEXT, kind TEXT, source TEXT NOT NULL) WITHOUT ROWID',
          )
          ..execute('CREATE TABLE catalog_meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
        for (final row in rows) {
          raw.execute('INSERT INTO catalog_packages VALUES (?, ?, ?, ?, ?, ?, ?, ?)', [
            row.barcode,
            row.name,
            row.brand,
            row.quantity,
            row.sizeValue,
            row.sizeUnit,
            row.kind,
            row.source,
          ]);
        }
        for (final (key, value) in [
          ('generated_at', '2026-10-29T00:00:00Z'),
          ('sources', 'off,opf,obf'),
          ('license', 'ODbL-1.0'),
          ('attribution', testCatalogAttribution),
          ('count', '${rows.length}'),
        ]) {
          raw.execute('INSERT INTO catalog_meta VALUES (?, ?)', [key, value]);
        }
        raw.userVersion = userVersion;
      },
    ),
  );
  // O drift só abre o arquivo (e roda o `setup`) na primeira consulta.
  await db.customSelect('SELECT 1').get();
  await db.close();
  return file;
}

final class _RawDatabase extends GeneratedDatabase {
  _RawDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];
}
