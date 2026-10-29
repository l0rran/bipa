import 'dart:io';

import 'package:bipa/core/catalog/product_kind.dart';
import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:bipa/features/products/domain/package_origin.dart';
import 'package:bipa/features/products/domain/product_catalog.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';

/// O asset do catálogo pronto (ADR 0024), gerado por `tool/catalogo`.
const catalogAsset = 'assets/catalog/catalogo.sqlite';

/// A versão do formato do arquivo (`PRAGMA user_version`) que este app lê.
/// Um arquivo de outro formato é tratado como catálogo ausente.
const catalogFormatVersion = 1;

/// Os bytes do asset do catálogo, ou `null` se o app não o tem.
typedef CatalogAssetLoader = Future<Uint8List?> Function();

/// Copia o catálogo do asset para a pasta de suporte do app, onde o SQLite
/// consegue abri-lo (o asset fica dentro do APK).
///
/// A cópia é refeita na primeira abertura de cada versão do app: o
/// catálogo é refeito a cada versão (ADR 0024). A pasta de suporte fica
/// fora do banco da pessoa e do Auto Backup, que só leva o
/// `backup/ultimo.bipa` (ADR 0023, seções 5 e 6).
final class CatalogInstaller {
  CatalogInstaller({
    required Future<Directory> Function() supportDirectory,
    required CatalogAssetLoader loadAsset,
    required Future<String?> Function() versionKey,
  }) : _supportDirectory = supportDirectory,
       _loadAsset = loadAsset,
       _versionKey = versionKey;

  final Future<Directory> Function() _supportDirectory;
  final CatalogAssetLoader _loadAsset;

  /// A versão do app ("0.2.0+3"). `null` refaz a cópia a cada execução,
  /// como num build de desenvolvimento, em que o catálogo muda sem a versão
  /// mudar.
  final Future<String?> Function() _versionKey;

  /// O arquivo do catálogo pronto para abrir, ou `null` se o app não tem o
  /// asset.
  Future<File?> install() async {
    final folder = Directory('${(await _supportDirectory()).path}${Platform.pathSeparator}catalogo');
    final file = File('${folder.path}${Platform.pathSeparator}catalogo.sqlite');
    final marker = File('${folder.path}${Platform.pathSeparator}versao');
    final key = await _versionKey();
    if (key != null && file.existsSync() && marker.existsSync() && marker.readAsStringSync() == key) return file;

    final bytes = await _loadAsset();
    if (bytes == null) {
      // Sem asset, uma cópia antiga também não vale: a versão nova do app
      // pode ter tirado o catálogo.
      if (folder.existsSync()) folder.deleteSync(recursive: true);
      return null;
    }
    folder.createSync(recursive: true);
    // Grava ao lado e troca com `rename`: um app fechado no meio da cópia não
    // deixa meio catálogo no lugar.
    final partial = File('${file.path}.novo');
    await partial.writeAsBytes(bytes, flush: true);
    if (marker.existsSync()) marker.deleteSync();
    partial.renameSync(file.path);
    if (key != null) marker.writeAsStringSync(key, flush: true);
    return file;
  }
}

/// O catálogo pronto, lido do arquivo SQLite que [install] devolve.
///
/// O arquivo abre só para leitura (`query_only`), numa conexão à parte do
/// banco da pessoa (ADR 0023, seção 6). Ele é instalado e aberto na primeira
/// consulta, não na abertura do app. Qualquer falha (sem asset, arquivo de
/// outro formato, SQLite que não abre) deixa o catálogo vazio, e o bipe
/// segue como sem ele.
final class SqliteProductCatalog implements ProductCatalog {
  SqliteProductCatalog({required Future<File?> Function() install, void Function(Object error)? onError})
    : _install = install,
      _onError = onError;

  final Future<File?> Function() _install;
  final void Function(Object error)? _onError;
  Future<_CatalogDatabase?>? _opening;

  Future<_CatalogDatabase?> _database() => _opening ??= _open();

  Future<_CatalogDatabase?> _open() async {
    _CatalogDatabase? db;
    try {
      final file = await _install();
      if (file == null) return null;
      db = _CatalogDatabase(
        NativeDatabase(
          file,
          // O drift não mexe no `user_version` nem cria tabelas: o arquivo é
          // do catálogo, não do app.
          enableMigrations: false,
          setup: (raw) => raw.execute('PRAGMA query_only = ON'),
        ),
      );
      final version = (await db.customSelect('PRAGMA user_version').getSingle()).read<int>('user_version');
      if (version != catalogFormatVersion) throw FormatException('catálogo no formato $version');
      return db;
    } on Object catch (error) {
      // Um erro aqui não pode impedir o bipe: o catálogo fica vazio.
      _onError?.call(error);
      await db?.close();
      return null;
    }
  }

  @override
  Future<CatalogPackage?> find(String barcode) async {
    final db = await _database();
    if (db == null) return null;
    try {
      final codes = _codeVariants(barcode.trim());
      final row = await db
          .customSelect(
            'SELECT barcode, name, brand, quantity, size_value, size_unit, kind, source FROM catalog_packages '
            'WHERE barcode IN (${List.filled(codes.length, '?').join(', ')}) LIMIT 1',
            variables: [for (final code in codes) Variable.withString(code)],
          )
          .getSingleOrNull();
      return row == null ? null : _package(row);
    } on Object catch (error) {
      _onError?.call(error);
      return null;
    }
  }

  @override
  Future<String?> attribution() async {
    final db = await _database();
    if (db == null) return null;
    try {
      final row = await db.customSelect("SELECT value FROM catalog_meta WHERE key = 'attribution'").getSingleOrNull();
      final text = row?.read<String>('value').trim();
      return text == null || text.isEmpty ? null : text;
    } on Object catch (error) {
      _onError?.call(error);
      return null;
    }
  }

  /// Fecha o arquivo. Uma consulta depois disso o abre de novo.
  Future<void> close() async {
    final opening = _opening;
    _opening = null;
    await (await opening)?.close();
  }

  /// O mesmo produto pode estar no catálogo como UPC-A (12 dígitos) ou
  /// como EAN-13 com um zero na frente, e a câmera pode ler qualquer um.
  static List<String> _codeVariants(String code) => [
    code,
    if (code.length == 12) '0$code',
    if (code.length == 13 && code.startsWith('0')) code.substring(1),
  ];

  static CatalogPackage _package(QueryRow row) {
    final brand = row.readNullable<String>('brand')?.trim();
    final quantity = row.readNullable<String>('quantity')?.trim();
    final size = row.readNullable<double>('size_value');
    return CatalogPackage(
      barcode: row.read<String>('barcode'),
      name: row.read<String>('name').trim(),
      brand: brand == null || brand.isEmpty ? null : brand,
      quantity: quantity == null || quantity.isEmpty ? null : quantity,
      size: size != null && size > 0 ? size : null,
      unit: _unit(row.readNullable<String>('size_unit')),
      kind: ProductKind.values.asNameMap()[row.readNullable<String>('kind')],
      source: _source(row.read<String>('source')),
    );
  }

  static MeasureUnit? _unit(String? unit) => switch (unit?.trim().toLowerCase()) {
    'g' => MeasureUnit.gram,
    'kg' => MeasureUnit.kilogram,
    'ml' => MeasureUnit.milliliter,
    'l' => MeasureUnit.liter,
    'un' => MeasureUnit.unit,
    _ => null,
  };

  /// Uma fonte desconhecida continua sendo do catálogo: na dúvida, o dado
  /// tem licença de terceiros (ADR 0024).
  static PackageOrigin _source(String source) => switch (source.trim().toLowerCase()) {
    'opf' => PackageOrigin.openProductsFacts,
    'obf' => PackageOrigin.openBeautyFacts,
    _ => PackageOrigin.openFoodFacts,
  };
}

/// Uma conexão do drift sem tabelas geradas: o catálogo só é lido com SQL.
final class _CatalogDatabase extends GeneratedDatabase {
  _CatalogDatabase(super.executor);

  @override
  int get schemaVersion => catalogFormatVersion;

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];
}
