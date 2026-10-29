import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:bipa/core/backup/app_data_swap.dart';
import 'package:bipa/core/database/app_database.dart';
import 'package:bipa/core/errors/domain_exception.dart';
import 'package:bipa/features/backup/data/drift_backup_database.dart';
import 'package:bipa/features/backup/data/local_backup_storage.dart';
import 'package:bipa/features/backup/data/zip_backup_archive.dart';
import 'package:bipa/features/backup/domain/backup_exception.dart';
import 'package:bipa/features/backup/domain/backup_info.dart';
import 'package:bipa/features/backup/domain/backup_manifest.dart';
import 'package:bipa/features/backup/domain/backup_ports.dart';
import 'package:bipa/features/backup/domain/create_backup.dart';
import 'package:bipa/features/backup/domain/read_latest_backup.dart';
import 'package:bipa/features/backup/domain/restore_backup.dart';
import 'package:bipa/features/backup/domain/restore_offer.dart';
import 'package:bipa/features/prices/domain/price_source.dart';
import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:bipa/features/stock/domain/stock_location.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/database/schemas/schema.dart';
import '../../helpers/fakes.dart';

/// O backup `.bipa` de ponta a ponta (ADR 0023, seção 5, lacuna B5), com
/// arquivos de verdade numa pasta temporária: o banco do app num arquivo, a
/// pasta de fotos, o `ultimo.bipa` e a área de restauração.
void main() {
  late Directory root;
  late _App app;
  final at = DateTime(2026, 10, 29, 8, 40);

  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    root = await Directory.systemTemp.createTemp('bipa_backup');
    app = _App(root, clock: () => at);
  });

  tearDown(() async {
    await app.close();
    await root.delete(recursive: true);
  });

  /// Uma casa: arroz com foto, um mercado, um preço, dois lotes em casa, e
  /// o café na lista.
  Future<void> seed() async {
    final db = app.db;
    await db
        .into(db.products)
        .insert(
          ProductsCompanion.insert(
            id: 'arroz',
            name: 'Arroz',
            unit: MeasureUnit.gram,
            photoPath: const Value('arroz.jpg'),
            createdAt: at,
            updatedAt: at,
          ),
        );
    await db
        .into(db.productPackages)
        .insert(
          ProductPackagesCompanion.insert(
            id: 'tio-joao',
            productId: 'arroz',
            barcode: const Value('7893500018469'),
            size: const Value(5000),
            unit: MeasureUnit.gram,
            createdAt: at,
            updatedAt: at,
          ),
        );
    await db.into(db.markets).insert(MarketsCompanion.insert(id: 'vila', name: 'Vila', createdAt: at, updatedAt: at));
    await db
        .into(db.priceObservations)
        .insert(
          PriceObservationsCompanion.insert(
            id: 'p1',
            productId: 'arroz',
            marketId: 'vila',
            packageId: const Value('tio-joao'),
            priceCents: 2899,
            source: PriceSource.priceTag,
            observedAt: at,
            createdAt: at,
            syncedAt: Value(at),
          ),
        );
    await db
        .into(db.stockItems)
        .insert(
          StockItemsCompanion.insert(productId: 'arroz', quantity: 2, location: StockLocation.pantry, updatedAt: at),
        );
    for (final id in ['l1', 'l2']) {
      await db
          .into(db.stockLots)
          .insert(
            StockLotsCompanion.insert(
              id: id,
              productId: 'arroz',
              packageId: const Value('tio-joao'),
              quantity: 1,
              since: at,
            ),
          );
    }
    await db
        .into(db.shoppingListItems)
        .insert(ShoppingListItemsCompanion.insert(id: 'cafe', name: 'Café', addedAt: at));
    app.writePhoto('arroz.jpg', [1, 2, 3, 4]);
  }

  /// Cada tabela como um conjunto de linhas em JSON: a ordem física pode
  /// mudar com o `VACUUM INTO` (ADR 0023, seção 3), o conteúdo não.
  Future<Map<String, Set<String>>> dump() async {
    final db = app.db;
    return {
      for (final table in db.allTables)
        table.actualTableName: {
          for (final row in await db.customSelect('SELECT * FROM "${table.actualTableName}"').get())
            jsonEncode(row.data),
        },
    };
  }

  /// Muda a casa depois do backup: o arroz some (com a foto), e o feijão
  /// entra.
  Future<void> changeEverything() async {
    final db = app.db;
    await (db.delete(db.products)..where((t) => t.id.equals('arroz'))).go();
    await db
        .into(db.products)
        .insert(
          ProductsCompanion.insert(id: 'feijao', name: 'Feijão', unit: MeasureUnit.gram, createdAt: at, updatedAt: at),
        );
    File(app.photo('arroz.jpg')).deleteSync();
    app.writePhoto('feijao.jpg', [9]);
  }

  /// Confere que a tentativa de restaurar [source] falhou com [code] (e,
  /// para garantir que foi pelo motivo certo, com [detail] no detalhe) e não
  /// mudou nada no aparelho.
  Future<void> expectRefused(String source, DomainErrorCode code, {String detail = ''}) async {
    final before = await dump();
    final photosBefore = app.photos();

    await expectLater(
      app.restore().prepare(source),
      throwsA(
        isA<BackupException>()
            .having((e) => e.code, 'code', code)
            .having((e) => e.detail ?? '', 'detail', contains(detail)),
      ),
    );

    expect(await dump(), before);
    expect(app.photos(), photosBefore);
    expect(Directory(joinPath(app.location.restoreAreaPath, 'novo')).existsSync(), isFalse);
    expect(await app.swap.hasReserve(), isFalse);
  }

  group('fazer backup', () {
    test('grava o ultimo.bipa com o manifesto, o banco e as fotos citadas', () async {
      await seed();
      app.writePhoto('orfa.jpg', [7]);

      final info = (await app.create()())!;

      expect(info.path, app.latestPath);
      expect(info.size, File(app.latestPath).lengthSync());
      expect(info.madeHere, isTrue);
      final manifest = info.manifest;
      expect((manifest.format, manifest.schemaVersion, manifest.appVersion), (1, app.db.schemaVersion, '0.1.0+1'));
      expect(manifest.createdAt, at);
      expect(manifest.counts['products'], 1);
      expect(manifest.counts['stock_lots'], 2);
      expect(manifest.counts, hasLength(app.db.allTables.length));
      expect(manifest.summary, const BackupSummary(products: 1, prices: 1, itemsAtHome: 1));
      // A foto órfã fica de fora (lacuna B2).
      expect(manifest.photos.map((photo) => photo.path), ['arroz.jpg']);

      final archive = ZipDecoder().decodeBytes(File(app.latestPath).readAsBytesSync());
      expect(archive.files.map((file) => file.name).toSet(), {'bipa.sqlite', 'fotos/arroz.jpg', 'manifest.json'});
      expect(await app.readLatest(), isNotNull);
    });

    test('um backup novo substitui o anterior de uma vez, sem sobras', () async {
      await seed();
      final first = (await app.create()())!;

      final second = (await app.create()())!;

      expect(second.manifest.id, isNot(first.manifest.id));
      expect((await app.readLatest())!.manifest.id, second.manifest.id);
      expect(Directory(joinPath(app.support.path, 'backup')).listSync().map((e) => e.uri.pathSegments.last).toSet(), {
        'ultimo.bipa',
        'ultimo.id',
      });
    });

    test('se o backup falha no meio, o ultimo.bipa anterior fica inteiro', () async {
      await seed();
      await app.create()();
      final before = File(app.latestPath).readAsBytesSync();

      final failing = app.create(archive: const _FailingArchive());
      await expectLater(failing(), throwsA(isA<FileSystemException>()));

      expect(File(app.latestPath).readAsBytesSync(), before);
      expect(Directory(joinPath(app.support.path, 'backup', 'trabalho')).existsSync(), isFalse);
    });

    test('"Salvar uma cópia…" escreve o mesmo arquivo no destino escolhido', () async {
      await seed();
      final destination = File(joinPath(root.path, 'escolhido.bipa'));

      final manifest = await app.create().saveCopy(destination.openWrite());

      expect(destination.readAsBytesSync(), File(app.latestPath).readAsBytesSync());
      expect((await app.readLatest())!.manifest.id, manifest.id);
    });
  });

  group('backup diário', () {
    test('grava na primeira abertura do dia, e não de novo no mesmo dia', () async {
      await seed();

      expect(await app.create()(trigger: BackupTrigger.daily), isNotNull);
      expect(await app.create(now: at.add(const Duration(hours: 3)))(trigger: BackupTrigger.daily), isNull);
      expect(await app.create(now: at.add(const Duration(days: 1)))(trigger: BackupTrigger.daily), isNotNull);
    });

    test('com o banco vazio, não grava', () async {
      expect(await app.create()(trigger: BackupTrigger.daily), isNull);
      expect(File(app.latestPath).existsSync(), isFalse);
    });
  });

  group('celular novo, com o ultimo.bipa trazido pelo Android', () {
    /// O aparelho antigo grava o backup; o novo recebe só o `ultimo.bipa`
    /// (sem a marca `ultimo.id`) e começa com o banco vazio.
    Future<String> arriveOnNewPhone() async {
      await seed();
      final info = (await app.create()())!;
      await app.close();
      File(app.location.databasePath).deleteSync();
      Directory(app.location.photosPath).deleteSync(recursive: true);
      File(joinPath(app.support.path, 'backup', 'ultimo.id')).deleteSync();
      await app.db.customSelect('SELECT 1').get();
      return info.manifest.id;
    }

    test('oferece restaurar, com a data e os números do manifesto', () async {
      final id = await arriveOnNewPhone();

      final offer = await app.offer()();

      expect(offer!.manifest.id, id);
      expect(offer.madeHere, isFalse);
      expect(offer.createdAt, at);
      expect(offer.manifest.summary, const BackupSummary(products: 1, prices: 1, itemsAtHome: 1));
    });

    test('nem o diário nem um backup manual do banco vazio gravam por cima', () async {
      final id = await arriveOnNewPhone();

      expect(await app.create(now: at.add(const Duration(days: 1)))(trigger: BackupTrigger.daily), isNull);
      expect(await app.create(now: at.add(const Duration(days: 1)))(), isNull);

      expect((await app.readLatest())!.manifest.id, id);
    });

    /// A casa já em uso no celular novo, antes de responder: um mercado.
    Future<void> startUsing() => app.db
        .into(app.db.markets)
        .insert(MarketsCompanion.insert(id: 'novo', name: 'Novo', createdAt: at, updatedAt: at));

    test('com a casa em uso, a oferta fica, sem prazo, e o diário segue pausado (BK1)', () async {
      final id = await arriveOnNewPhone();
      await startUsing();

      // Um mês depois, ainda sem resposta.
      final later = at.add(const Duration(days: 30));
      expect((await app.offer()())!.manifest.id, id);
      expect(await app.create(now: later)(trigger: BackupTrigger.daily), isNull);
      expect((await app.readLatest())!.manifest.id, id);
      expect((await app.readLatest())!.madeHere, isFalse);
    });

    test('"Fazer backup agora" não grava por cima sem a confirmação (BK1)', () async {
      final id = await arriveOnNewPhone();
      await startUsing();

      expect(await app.create()(), isNull);
      expect((await app.readLatest())!.manifest.id, id);
    });

    test('"Apagar e fazer backup" grava por cima, e o diário volta', () async {
      final id = await arriveOnNewPhone();
      await startUsing();

      final made = await app.create()(replacePending: true);

      expect(made, isNotNull);
      expect(made!.manifest.id, isNot(id));
      final latest = (await app.readLatest())!;
      expect((latest.manifest.id, latest.madeHere), (made.manifest.id, true));
      expect(await app.offer()(), isNull);
      expect(await app.create(now: at.add(const Duration(days: 1)))(trigger: BackupTrigger.daily), isNotNull);
    });

    test('mesmo com a confirmação, um banco vazio não toma o lugar do backup do outro celular', () async {
      final id = await arriveOnNewPhone();

      expect(await app.create()(replacePending: true), isNull);
      expect((await app.readLatest())!.manifest.id, id);
    });

    test('"Salvar uma cópia…" grava só a cópia, sem tocar no backup do outro celular', () async {
      final id = await arriveOnNewPhone();
      await startUsing();
      final copy = joinPath(root.path, 'copia.bipa');

      final manifest = await app.create().saveCopy(File(copy).openWrite());

      expect(manifest.id, isNot(id));
      expect((await const ZipBackupArchive().readManifest(copy)).id, manifest.id);
      final latest = (await app.readLatest())!;
      expect((latest.manifest.id, latest.madeHere), (id, false));
    });

    test('"Deixar de lado" com a casa em uso: a oferta some e o próximo diário grava por cima', () async {
      final id = await arriveOnNewPhone();
      await startUsing();

      await app.offer().dismiss((await app.offer()())!);

      expect(await app.offer()(), isNull);
      final daily = await app.create(now: at.add(const Duration(days: 1)))(trigger: BackupTrigger.daily);
      expect(daily, isNotNull);
      expect((await app.readLatest())!.manifest.id, isNot(id));
    });

    test('"Começar do zero" tira a oferta; o arquivo continua restaurável até o próximo diário', () async {
      await arriveOnNewPhone();
      final offer = (await app.offer()())!;

      await app.offer().dismiss(offer);

      expect(await app.offer()(), isNull);
      expect((await app.readLatest())!.madeHere, isTrue);
      await app.restore()(app.latestPath);
      expect((await dump())['products'], hasLength(1));
    });

    test('casa vazia por completo: a restauração não apaga nada (BK4)', () async {
      await arriveOnNewPhone();

      final prepared = await app.restore().prepare(app.latestPath);

      expect(prepared.current, BackupSummary.empty);
      expect(prepared.currentIsEmpty, isTrue);
    });

    test('uma lista escrita à mão não entra nos três números, mas a casa não está vazia (BK4)', () async {
      await arriveOnNewPhone();
      await app.db
          .into(app.db.shoppingListItems)
          .insert(ShoppingListItemsCompanion.insert(id: 'pao', name: 'Pão', addedAt: at));

      final prepared = await app.restore().prepare(app.latestPath);

      expect(prepared.current, BackupSummary.empty);
      expect(prepared.currentIsEmpty, isFalse);
    });

    test('um mercado criado não entra nos três números, mas a casa não está vazia (BK4)', () async {
      await arriveOnNewPhone();
      await app.db
          .into(app.db.markets)
          .insert(MarketsCompanion.insert(id: 'bairro', name: 'Mercado do bairro', createdAt: at, updatedAt: at));

      final prepared = await app.restore().prepare(app.latestPath);

      expect(prepared.current, BackupSummary.empty);
      expect(prepared.currentIsEmpty, isFalse);
    });

    test('restaurar a oferta traz a casa e as fotos', () async {
      await arriveOnNewPhone();

      await app.restore()(app.latestPath);

      expect((await dump())['products'], hasLength(1));
      expect(app.photos(), {'arroz.jpg': '1,2,3,4'});
      expect(await app.offer()(), isNull);
    });
  });

  group('restaurar', () {
    test('ida e volta: os dados e as fotos ficam iguais aos do backup', () async {
      await seed();
      final before = await dump();
      final photos = app.photos();
      await app.create()();
      await changeEverything();

      final prepared = await app.restore().prepare(app.latestPath);
      expect(prepared.backup, const BackupSummary(products: 1, prices: 1, itemsAtHome: 1));
      expect(prepared.current, const BackupSummary(products: 1, prices: 0, itemsAtHome: 0));
      expect(prepared.adjustedItems, 0);
      await app.restore().apply(prepared);

      expect(await dump(), before);
      expect(app.photos(), photos);
      // O `synced_at` fica como estava no backup.
      expect((await app.db.select(app.db.priceObservations).getSingle()).syncedAt, at);
    });

    test('restaurar o mesmo arquivo duas vezes dá o mesmo resultado', () async {
      await seed();
      await app.create()();
      await changeEverything();

      await app.restore()(app.latestPath);
      final once = await dump();
      final photosOnce = app.photos();
      await app.restore()(app.latestPath);

      expect(await dump(), once);
      expect(app.photos(), photosOnce);
    });

    test('cancelar depois de conferir não muda nada', () async {
      await seed();
      await app.create()();
      await changeEverything();
      final before = await dump();

      final prepared = await app.restore().prepare(app.latestPath);
      await app.restore().cancel(prepared);

      expect(await dump(), before);
      expect(Directory(prepared.workspace.path).existsSync(), isFalse);
    });

    test('"Desfazer" volta os dados e as fotos de antes da restauração', () async {
      await seed();
      await app.create()();
      await changeEverything();
      final before = await dump();
      final photos = app.photos();

      await app.restore()(app.latestPath);
      expect(await app.restore().undo(), isTrue);

      expect(await dump(), before);
      expect(app.photos(), photos);
      expect(await app.restore().undo(), isFalse);
    });

    test('depois do prazo, a reserva sai e não há o que desfazer', () async {
      await seed();
      await app.create()();
      await changeEverything();
      await app.restore()(app.latestPath);
      final restored = await dump();

      await app.restore().discardUndo();

      expect(await app.restore().undo(), isFalse);
      expect(await dump(), restored);
    });

    test('lotes que não somam a quantidade em casa: a quantidade vira a soma (ADR 0013)', () async {
      await seed();
      final file = joinPath(root.path, 'lotes.sqlite');
      await app.db.customStatement('VACUUM INTO ?', [file]);
      final seconds = at.millisecondsSinceEpoch ~/ 1000;
      // O arroz fica com 2 em casa e um lote de 1; o feijão tem um lote de 3
      // e nenhum item.
      await _raw(file, "DELETE FROM stock_lots WHERE id = 'l2'");
      await _raw(
        file,
        'INSERT INTO products (id, name, unit, created_at, updated_at) '
        "VALUES ('feijao', 'Feijão', 'gram', $seconds, $seconds)",
      );
      await _raw(file, "INSERT INTO stock_lots (id, product_id, quantity, since) VALUES ('l3', 'feijao', 3, $seconds)");
      final source = await app.archiveOf(file, schemaVersion: app.db.schemaVersion);
      await changeEverything();

      final prepared = await app.restore().prepare(source);
      expect(prepared.adjustedItems, 2);
      expect(prepared.backup, const BackupSummary(products: 2, prices: 1, itemsAtHome: 2));
      await app.restore().apply(prepared);

      final items = {
        for (final item in await app.db.select(app.db.stockItems).get()) item.productId: (item.quantity, item.location),
      };
      expect(items, {'arroz': (1.0, StockLocation.pantry), 'feijao': (3.0, StockLocation.pantry)});
    });

    test('um backup que chega como fluxo de bytes também se restaura', () async {
      await seed();
      await app.create()();
      final before = await dump();
      await changeEverything();

      final prepared = await app.restore().prepareBytes(File(app.latestPath).openRead());
      await app.restore().apply(prepared);

      expect(await dump(), before);
    });
  });

  group('esquemas', () {
    test('um backup do esquema 14 guardado (drift_schemas/) abre no app atual', () async {
      final verifier = SchemaVerifier(GeneratedHelper());
      final schema = await verifier.schemaAt(14);
      final seconds = at.millisecondsSinceEpoch ~/ 1000;
      schema.rawDatabase
        ..execute(
          'INSERT INTO products (id, name, unit, created_at, updated_at) '
          "VALUES ('atum', 'Atum', 'unit', $seconds, $seconds)",
        )
        ..execute(
          'INSERT INTO stock_items (product_id, quantity, location, updated_at) '
          "VALUES ('atum', 1, 'pantry', $seconds)",
        )
        ..execute(
          'INSERT INTO stock_lots (id, product_id, quantity, since) '
          "VALUES ('l1', 'atum', 1, $seconds)",
        );
      final file = joinPath(root.path, 'v14.sqlite');
      schema.rawDatabase.execute("VACUUM INTO '$file'");
      schema.close();
      final source = await app.archiveOf(file, schemaVersion: 14);

      await app.restore()(source);

      final item = await app.db.select(app.db.stockItems).getSingle();
      expect((item.productId, item.quantity, item.location), ('atum', 1.0, StockLocation.pantry));
    });

    test('um backup de esquema mais antigo passa pela migração do drift', () async {
      // Simula a v13 como o teste de migração: sem a tabela da v14 e sem a
      // coluna da v15.
      await seed();
      final file = joinPath(root.path, 'v13.sqlite');
      await app.db.customStatement('VACUUM INTO ?', [file]);
      await _raw(file, 'DROP TABLE remembered_locations');
      await _raw(file, 'ALTER TABLE product_packages DROP COLUMN origin');
      _setUserVersion(file, 13);
      final source = await app.archiveOf(file, schemaVersion: 13, counts: {'products': 1});
      await changeEverything();

      await app.restore()(source);

      expect((await dump())['products'], hasLength(1));
      expect(await app.db.select(app.db.rememberedLocations).get(), isEmpty);
    });

    test('recusa um backup de esquema mais novo, sem mexer em nada', () async {
      await seed();
      await app.create()();
      final newer = app.db.schemaVersion + 1;
      final source = app.rewriteManifest(app.latestPath, (json) => json..['schemaVersion'] = newer);

      await expectRefused(source, DomainErrorCode.backupFromNewerApp, detail: 'esquema $newer');
    });

    test('recusa um banco com user_version mais novo que o do app', () async {
      await seed();
      final newer = app.db.schemaVersion + 1;
      final file = joinPath(root.path, 'mais_novo.sqlite');
      await app.db.customStatement('VACUUM INTO ?', [file]);
      _setUserVersion(file, newer);
      final source = await app.archiveOf(file, schemaVersion: app.db.schemaVersion);

      await expectRefused(source, DomainErrorCode.backupFromNewerApp, detail: 'user_version $newer');
    });

    test('recusa um formato mais novo', () async {
      await seed();
      await app.create()();
      final source = app.rewriteManifest(app.latestPath, (json) => json..['format'] = 2);

      await expectRefused(source, DomainErrorCode.backupFromNewerApp, detail: 'formato 2');
    });

    test('um valor de enum que este app não conhece pede app mais novo (B4)', () async {
      await seed();
      final file = joinPath(root.path, 'enum.sqlite');
      await app.db.customStatement('VACUUM INTO ?', [file]);
      await _raw(file, "UPDATE products SET unit = 'lightYear'");
      final source = await app.archiveOf(file, schemaVersion: app.db.schemaVersion);

      await expectRefused(source, DomainErrorCode.backupFromNewerApp, detail: 'products');
    });
  });

  group('arquivos que não servem não mudam nada', () {
    setUp(() async {
      await seed();
      await app.create()();
    });

    test('um arquivo que não é zip', () async {
      final source = joinPath(root.path, 'foto.bipa');
      File(source).writeAsBytesSync(List.generate(4096, (i) => i * 7 % 256));

      await expectRefused(source, DomainErrorCode.backupNotRecognized);
    });

    test('um arquivo cortado no meio (a cópia que não terminou de subir)', () async {
      final bytes = File(app.latestPath).readAsBytesSync();
      final source = joinPath(root.path, 'cortado.bipa');
      File(source).writeAsBytesSync(bytes.sublist(0, bytes.length ~/ 2));

      await expectRefused(source, DomainErrorCode.backupNotRecognized);
    });

    test('um zip sem manifesto', () async {
      final source = app.rebuild(app.latestPath, drop: 'manifest.json');

      await expectRefused(source, DomainErrorCode.backupNotRecognized, detail: 'sem manifesto');
    });

    test('um manifesto que não é JSON, ou sem campos', () async {
      final notJson = app.rebuild(app.latestPath, replace: {'manifest.json': utf8.encode('{"format": 1, ')});
      final missing = app.rewriteManifest(app.latestPath, (json) => json..remove('database'));

      await expectRefused(notJson, DomainErrorCode.backupNotRecognized, detail: 'JSON');
      await expectRefused(missing, DomainErrorCode.backupNotRecognized, detail: 'campos');
    });

    test('uma foto com caminho para fora da pasta', () async {
      final source = app.rewriteManifest(app.latestPath, (json) {
        (json['photos']! as List<Object?>).add({'path': '../bipa.sqlite', 'sha256': '0' * 64, 'size': 1});
        return json;
      });

      await expectRefused(source, DomainErrorCode.backupNotRecognized, detail: 'entrada');
    });

    test('um banco que não bate com o hash', () async {
      final archive = ZipDecoder().decodeBytes(File(app.latestPath).readAsBytesSync());
      final database = archive.findFile('bipa.sqlite')!.readBytes()!;
      database[database.length - 1] ^= 0xff;
      final source = app.rebuild(app.latestPath, replace: {'bipa.sqlite': database});

      await expectRefused(source, DomainErrorCode.backupDamaged, detail: 'bipa.sqlite não confere');
    });

    test('uma foto que falta', () async {
      final source = app.rebuild(app.latestPath, drop: 'fotos/arroz.jpg');

      await expectRefused(source, DomainErrorCode.backupDamaged, detail: 'falta fotos/arroz.jpg');
    });

    test('um banco que não é SQLite, com o hash certo', () async {
      final source = await app.archiveBytesOf(
        utf8.encode('não sou um banco' * 20),
        schemaVersion: app.db.schemaVersion,
      );

      await expectRefused(source, DomainErrorCode.backupDamaged, detail: 'não é SQLite');
    });

    test('contagens que não batem com o manifesto', () async {
      final file = joinPath(root.path, 'contagem.sqlite');
      await app.db.customStatement('VACUUM INTO ?', [file]);
      final source = await app.archiveOf(file, schemaVersion: app.db.schemaVersion, counts: {'products': 5});

      await expectRefused(source, DomainErrorCode.backupDamaged, detail: 'products tem 1 linhas');
    });

    test('chave estrangeira quebrada', () async {
      final file = joinPath(root.path, 'chave.sqlite');
      await app.db.customStatement('VACUUM INTO ?', [file]);
      await _raw(file, "UPDATE price_observations SET market_id = 'sumiu'");
      final source = await app.archiveOf(file, schemaVersion: app.db.schemaVersion);

      await expectRefused(source, DomainErrorCode.backupDamaged, detail: 'foreign_key_check');
    });
  });
}

/// Roda [sql] direto num arquivo do SQLite, antes de o drift ligar as
/// chaves estrangeiras.
Future<void> _raw(String file, String sql) async {
  final db = AppDatabase(NativeDatabase(File(file), setup: (raw) => raw.execute(sql)));
  // O drift só abre o arquivo (e roda o `setup`) na primeira consulta.
  await db.customSelect('SELECT 1').get();
  await db.close();
}

/// Grava [version] no `user_version` do cabeçalho do SQLite (bytes 60 a
/// 63), sem abrir o banco: abrir com o drift rodaria a migração.
void _setUserVersion(String file, int version) {
  final handle = File(file).openSync(mode: FileMode.append)
    ..setPositionSync(60)
    ..writeFromSync([version >> 24 & 0xff, version >> 16 & 0xff, version >> 8 & 0xff, version & 0xff]);
  handle.closeSync();
}

/// O app numa pasta temporária: o banco em arquivo, que fecha e reabre como
/// no app, e os use cases ligados às implementações de verdade.
final class _App {
  _App(Directory root, {required this.clock})
    : location = AppDataLocation(joinPath(root.path, 'documentos')),
      support = Directory(joinPath(root.path, 'suporte')) {
    Directory(location.photosPath).createSync(recursive: true);
    support.createSync(recursive: true);
  }

  final AppDataLocation location;
  final Directory support;
  final DateTime Function() clock;
  final ids = SequentialIdGenerator();
  late final swap = AppDataSwap(location);

  AppDatabase? _db;

  /// O banco aberto agora; depois de [close], abre de novo.
  AppDatabase get db => _db ??= AppDatabase(NativeDatabase(File(location.databasePath)));

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  late final storage = LocalBackupStorage(
    location: () async => location,
    supportDirectory: () async => support,
    closeDatabase: close,
    reopenDatabase: () {},
  );

  late final database = _LiveDatabase(this);

  String get latestPath => joinPath(support.path, 'backup', 'ultimo.bipa');

  CreateBackup create({BackupArchive archive = const ZipBackupArchive(), DateTime? now}) => CreateBackup(
    database: database,
    archive: archive,
    storage: storage,
    appVersion: () async => '0.1.0+1',
    clock: now == null ? clock : () => now,
    ids: ids,
  );

  RestoreBackup restore() => RestoreBackup(database: database, archive: const ZipBackupArchive(), storage: storage);

  RestoreOffer offer() => RestoreOffer(storage: storage, archive: const ZipBackupArchive());

  Future<BackupInfo?> readLatest() => ReadLatestBackup(storage: storage, archive: const ZipBackupArchive())();

  String photo(String name) => joinPath(location.photosPath, name);

  void writePhoto(String name, List<int> bytes) => File(photo(name))
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes);

  /// As fotos no aparelho, com o conteúdo.
  Map<String, String> photos() {
    final directory = Directory(location.photosPath);
    if (!directory.existsSync()) return {};
    return {
      for (final file in directory.listSync(recursive: true).whereType<File>())
        file.uri.pathSegments.last: file.readAsBytesSync().join(','),
    };
  }

  var _made = 0;

  /// Um `.bipa` com o banco em [databaseFile], montado como o app monta, mas
  /// com o [schemaVersion] e as [counts] que o teste quiser.
  Future<String> archiveOf(
    String databaseFile, {
    required int schemaVersion,
    Map<String, int> counts = const {},
  }) async {
    final target = joinPath(Directory(databaseFile).parent.path, 'feito-${++_made}.bipa');
    await const ZipBackupArchive().write(
      target: target,
      draft: BackupDraft(
        id: 'feito-$_made',
        createdAt: clock(),
        appVersion: '0.0.1',
        schemaVersion: schemaVersion,
        counts: counts,
        summary: BackupSummary.empty,
      ),
      databasePath: databaseFile,
      photosPath: location.photosPath,
      photoPaths: const [],
    );
    return target;
  }

  /// [archiveOf] com um "banco" que são só estes bytes.
  Future<String> archiveBytesOf(List<int> bytes, {required int schemaVersion}) async {
    final file = joinPath(support.path, 'bytes-${++_made}.sqlite');
    File(file).writeAsBytesSync(bytes);
    return archiveOf(file, schemaVersion: schemaVersion);
  }

  /// Uma cópia do zip em [source] sem [drop] e com as entradas de [replace].
  String rebuild(String source, {String? drop, Map<String, List<int>> replace = const {}}) {
    final original = ZipDecoder().decodeBytes(File(source).readAsBytesSync());
    final copy = Archive();
    for (final file in original.files) {
      if (file.name == drop) continue;
      copy.addFile(ArchiveFile.bytes(file.name, replace[file.name] ?? file.readBytes()!));
    }
    final target = joinPath(support.path, 'refeito-${++_made}.bipa');
    File(target).writeAsBytesSync(ZipEncoder().encodeBytes(copy));
    return target;
  }

  /// [rebuild] com o manifesto mudado por [change].
  String rewriteManifest(String source, Map<String, Object?> Function(Map<String, Object?> json) change) {
    final original = ZipDecoder().decodeBytes(File(source).readAsBytesSync());
    final json = jsonDecode(utf8.decode(original.findFile('manifest.json')!.readBytes()!)) as Map<String, Object?>;
    return rebuild(source, replace: {'manifest.json': utf8.encode(jsonEncode(change(json)))});
  }
}

/// O [DriftBackupDatabase] do banco aberto agora, que muda quando a
/// restauração fecha e reabre (no app, o provider faz isso).
final class _LiveDatabase implements BackupDatabase {
  _LiveDatabase(this._app);

  final _App _app;

  DriftBackupDatabase get _current => DriftBackupDatabase(_app.db);

  @override
  int get schemaVersion => _current.schemaVersion;

  @override
  Future<void> copyTo(String path) => _current.copyTo(path);

  @override
  Future<BackupContents> describe(String path) => _current.describe(path);

  @override
  Future<CheckedBackup> check(String path, BackupManifest manifest) => _current.check(path, manifest);

  @override
  Future<BackupSummary> currentSummary() => _current.currentSummary();

  @override
  Future<bool> isEmpty() => _current.isEmpty();
}

/// Um zip que falha no meio da gravação.
final class _FailingArchive implements BackupArchive {
  const _FailingArchive();

  @override
  Future<BackupManifest> readManifest(String source) => const ZipBackupArchive().readManifest(source);

  @override
  Future<void> extract({
    required String source,
    required BackupManifest manifest,
    required String databasePath,
    required String photosPath,
  }) => throw UnimplementedError();

  @override
  Future<BackupManifest> write({
    required String target,
    required BackupDraft draft,
    required String databasePath,
    required String photosPath,
    required Iterable<String> photoPaths,
  }) async {
    File(target).writeAsStringSync('metade');
    throw const FileSystemException('disco cheio');
  }
}
