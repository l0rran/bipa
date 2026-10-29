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
        restoreUndoWindowProvider.overrideWithValue(const Duration(milliseconds: 50)),
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

  test('depois do prazo, o desfazer não vale mais', () async {
    await addProduct('arroz', 'Arroz');
    final backup = (await controller().createBackup())!;
    await addProduct('feijao', 'Feijão');

    await controller().restore(File(backup.path));
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(container.read(backupProvider).value?.canUndoRestore, isFalse);
    expect(await controller().undoRestore(), isFalse);
    final db = container.read(appDatabaseProvider);
    expect((await db.select(db.products).get()).map((row) => row.name), ['Arroz']);
  });
}
