import 'dart:io';

import 'package:bipa/core/backup/app_data_swap.dart';
import 'package:bipa/core/database/app_database.dart';
import 'package:bipa/core/database/database_provider.dart';
import 'package:bipa/core/di/core_providers.dart';
import 'package:bipa/features/backup/data/local_backup_storage.dart';
import 'package:bipa/features/backup/presentation/backup_providers.dart';
import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

/// O `backupProvider` com o banco num arquivo: a restauração fecha o banco,
/// troca os arquivos e o [appDatabaseProvider] recarrega, levando junto o
/// que o observa.
void main() {
  late Directory root;
  late AppDataLocation location;
  late ProviderContainer container;
  final at = DateTime(2026, 10, 29, 8, 40);

  /// Os nomes dos produtos, como uma tela os veria.
  final productNamesProvider = StreamProvider<List<String>>(
    (ref) => ref
        .watch(appDatabaseProvider)
        .select(ref.watch(appDatabaseProvider).products)
        .watch()
        .map((rows) => [for (final row in rows) row.name]..sort()),
  );

  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    root = await Directory.systemTemp.createTemp('bipa_backup_provider');
    location = AppDataLocation(joinPath(root.path, 'documentos'));
    final support = Directory(joinPath(root.path, 'suporte'))..createSync(recursive: true);
    Directory(location.photosPath).createSync(recursive: true);
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWith((ref) {
          final db = AppDatabase(NativeDatabase(File(location.databasePath)));
          ref.onDispose(db.close);
          return db;
        }),
        backupStorageProvider.overrideWith(
          (ref) => LocalBackupStorage(
            location: () async => location,
            supportDirectory: () async => support,
            closeDatabase: () => ref.read(appDatabaseProvider).close(),
            reopenDatabase: () => ref.invalidate(appDatabaseProvider),
          ),
        ),
        backupAppVersionProvider.overrideWithValue(() async => '0.1.0+1'),
        clockProvider.overrideWithValue(() => at),
        idGeneratorProvider.overrideWithValue(SequentialIdGenerator()),
      ],
    );
  });

  tearDown(() async {
    // O provider fecha o banco sem esperar; aqui é preciso esperar para
    // apagar a pasta (o fechar é idempotente).
    final db = container.read(appDatabaseProvider);
    container.dispose();
    await db.close();
    await root.delete(recursive: true);
  });

  Future<void> addProduct(String id, String name) {
    final db = container.read(appDatabaseProvider);
    return db
        .into(db.products)
        .insert(ProductsCompanion.insert(id: id, name: name, unit: MeasureUnit.unit, createdAt: at, updatedAt: at));
  }

  BackupController controller() => container.read(backupProvider.notifier);

  test('fazer backup atualiza o último backup', () async {
    await addProduct('arroz', 'Arroz');
    expect((await container.read(backupProvider.future)).lastBackup, isNull);

    final info = await controller().createBackup();

    expect(info, isNotNull);
    expect(controller().lastBackupInfo?.manifest.id, info!.manifest.id);
    expect(backupFileName(info.createdAt), 'bipa-2026-10-29.bipa');
  });

  test('o backup diário grava uma vez por dia', () async {
    await addProduct('arroz', 'Arroz');

    await controller().runDailyBackup();
    final first = controller().lastBackupInfo;
    await controller().runDailyBackup();

    expect(first, isNotNull);
    expect(controller().lastBackupInfo?.manifest.id, first!.manifest.id);
  });

  test('restaurar recarrega quem observa o banco, e o desfazer volta', () async {
    await addProduct('arroz', 'Arroz');
    final backup = (await controller().createBackup())!;
    await addProduct('feijao', 'Feijão');
    final names = container.listen(productNamesProvider, (_, _) {});
    expect(await container.read(productNamesProvider.future), ['Arroz', 'Feijão']);

    final prepared = await controller().prepareRestore(File(backup.path));
    expect((prepared.backup.products, prepared.current.products), (1, 2));
    await controller().applyRestore(prepared);

    expect(await container.read(productNamesProvider.future), ['Arroz']);
    expect(container.read(backupProvider).value?.canUndoRestore, isTrue);

    expect(await controller().undoRestore(), isTrue);
    expect(await container.read(productNamesProvider.future), ['Arroz', 'Feijão']);
    expect(container.read(backupProvider).value?.canUndoRestore, isFalse);
    names.close();
  });

  test('o desfazer não tem relógio próprio: vale enquanto o aviso não o descarta', () async {
    await addProduct('arroz', 'Arroz');
    final backup = (await controller().createBackup())!;
    await addProduct('feijao', 'Feijão');

    await controller().restore(File(backup.path));
    // Muito além dos 10 s do aviso: quem decide é o aviso (BK2).
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(container.read(backupProvider).value?.canUndoRestore, isTrue);
    expect(await controller().undoRestore(), isTrue);
    final db = container.read(appDatabaseProvider);
    expect((await db.select(db.products).get()).map((row) => row.name), ['Arroz', 'Feijão']);
  });

  group('backup de outro celular sem resposta (BK1)', () {
    /// O `ultimo.bipa` passa a ser de outro aparelho, como o Auto Backup do
    /// Android o traz, e a casa já está em uso.
    Future<String> arriveFromOtherPhone() async {
      await addProduct('arroz', 'Arroz');
      final id = (await controller().createBackup())!.manifest.id;
      File(joinPath(root.path, 'suporte', 'backup', 'ultimo.id')).deleteSync();
      await addProduct('feijao', 'Feijão');
      container.invalidate(backupProvider);
      await container.read(backupProvider.future);
      return id;
    }

    test('fica pendente: o cartão e Ajustes o oferecem, e o diário não grava', () async {
      final id = await arriveFromOtherPhone();

      final state = container.read(backupProvider).value!;
      expect(state.pending, isTrue);
      expect(state.restoreOffer?.manifest.id, id);

      await controller().runDailyBackup();
      expect(controller().lastBackupInfo?.manifest.id, id);
      expect(container.read(backupProvider).value!.pending, isTrue);
    });

    test('"Deixar de lado" com Desfazer: o cartão volta, e o backup continua pendente', () async {
      final id = await arriveFromOtherPhone();

      final hidden = controller().hideRestoreOffer()!;
      expect(container.read(backupProvider).value!.restoreOffer, isNull);
      expect(container.read(backupProvider).value!.pending, isTrue, reason: 'até o aviso sair, Ajustes ainda pergunta');

      controller().bringBackRestoreOffer(hidden);
      expect(container.read(backupProvider).value!.restoreOffer?.manifest.id, id);
      await controller().runDailyBackup();
      expect(controller().lastBackupInfo?.manifest.id, id);
    });

    test('"Deixar de lado" valendo: o arquivo é adotado e o diário volta a gravar', () async {
      final id = await arriveFromOtherPhone();

      final hidden = controller().hideRestoreOffer()!;
      await controller().dismissRestoreOffer(hidden);

      final state = container.read(backupProvider).value!;
      expect((state.pending, state.restoreOffer), (false, null));
      // O backup do outro celular ainda é o último, até o diário seguinte.
      expect(state.lastBackup?.manifest.id, id);
    });

    test('"Fazer backup agora" só grava por cima com a confirmação', () async {
      final id = await arriveFromOtherPhone();

      expect(await controller().createBackup(), isNull);
      expect(controller().lastBackupInfo?.manifest.id, id);

      final made = await controller().createBackup(replacePending: true);
      final state = container.read(backupProvider).value!;
      expect(state.lastBackup?.manifest.id, made!.manifest.id);
      expect((state.pending, state.restoreOffer), (false, null));
    });
  });

  test('o aviso saiu sem o desfazer: a reserva é descartada', () async {
    await addProduct('arroz', 'Arroz');
    final backup = (await controller().createBackup())!;
    await addProduct('feijao', 'Feijão');

    await controller().restore(File(backup.path));
    await controller().discardRestoreUndo(controller().restoreEpoch);

    expect(container.read(backupProvider).value?.canUndoRestore, isFalse);
    expect(await controller().undoRestore(), isFalse);
    final db = container.read(appDatabaseProvider);
    expect((await db.select(db.products).get()).map((row) => row.name), ['Arroz']);
  });

  test('o aviso de uma restauração antiga não descarta a reserva da nova', () async {
    await addProduct('arroz', 'Arroz');
    final backup = (await controller().createBackup())!;
    await addProduct('feijao', 'Feijão');

    await controller().restore(File(backup.path));
    final first = controller().restoreEpoch;
    await addProduct('leite', 'Leite');
    await controller().restore(File(backup.path));

    // O aviso novo tira o antigo, que avisa que saiu.
    await controller().discardRestoreUndo(first);

    expect(container.read(backupProvider).value?.canUndoRestore, isTrue);
    expect(await controller().undoRestore(), isTrue);
    final db = container.read(appDatabaseProvider);
    expect((await db.select(db.products).get()).map((row) => row.name), unorderedEquals(['Arroz', 'Leite']));
  });
}
