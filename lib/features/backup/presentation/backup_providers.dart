import 'dart:async';
import 'dart:io';

import 'package:bipa/core/backup/app_data_swap.dart';
import 'package:bipa/core/database/database_provider.dart';
import 'package:bipa/core/di/core_providers.dart';
import 'package:bipa/features/backup/data/drift_backup_database.dart';
import 'package:bipa/features/backup/data/local_backup_storage.dart';
import 'package:bipa/features/backup/data/zip_backup_archive.dart';
import 'package:bipa/features/backup/domain/backup_info.dart';
import 'package:bipa/features/backup/domain/backup_manifest.dart';
import 'package:bipa/features/backup/domain/backup_ports.dart';
import 'package:bipa/features/backup/domain/create_backup.dart';
import 'package:bipa/features/backup/domain/read_latest_backup.dart';
import 'package:bipa/features/backup/domain/restore_backup.dart';
import 'package:bipa/features/backup/domain/restore_offer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

/// Os arquivos do backup. Fechar e reabrir o banco passa pelo
/// [appDatabaseProvider]: depois de uma restauração, ele é descartado, e
/// tudo o que o observa (repositórios, listas, telas) recarrega com o banco
/// novo.
final backupStorageProvider = Provider<BackupStorage>(
  (ref) => LocalBackupStorage(
    location: appDataLocation,
    supportDirectory: getApplicationSupportDirectory,
    closeDatabase: () => ref.read(appDatabaseProvider).close(),
    reopenDatabase: () => ref.invalidate(appDatabaseProvider),
  ),
);

final backupDatabaseProvider = Provider<BackupDatabase>((ref) => DriftBackupDatabase(ref.watch(appDatabaseProvider)));

final backupArchiveProvider = Provider<BackupArchive>((ref) => const ZipBackupArchive());

/// A versão do app gravada no manifesto (`0.1.0+1`).
final backupAppVersionProvider = Provider<Future<String> Function()>(
  (ref) => () async {
    final info = await PackageInfo.fromPlatform();
    return '${info.version}+${info.buildNumber}';
  },
);

/// Quanto tempo o "Desfazer" de uma restauração fica disponível.
final restoreUndoWindowProvider = Provider<Duration>((ref) => RestoreBackup.undoWindow);

final createBackupProvider = Provider<CreateBackup>(
  (ref) => CreateBackup(
    database: ref.watch(backupDatabaseProvider),
    archive: ref.watch(backupArchiveProvider),
    storage: ref.watch(backupStorageProvider),
    appVersion: ref.watch(backupAppVersionProvider),
    clock: ref.watch(clockProvider),
    ids: ref.watch(idGeneratorProvider),
  ),
);

final restoreBackupProvider = Provider<RestoreBackup>(
  (ref) => RestoreBackup(
    database: ref.watch(backupDatabaseProvider),
    archive: ref.watch(backupArchiveProvider),
    storage: ref.watch(backupStorageProvider),
  ),
);

final restoreOfferProvider = Provider<RestoreOffer>(
  (ref) => RestoreOffer(
    database: ref.watch(backupDatabaseProvider),
    storage: ref.watch(backupStorageProvider),
    archive: ref.watch(backupArchiveProvider),
  ),
);

final readLatestBackupProvider = Provider<ReadLatestBackup>(
  (ref) => ReadLatestBackup(storage: ref.watch(backupStorageProvider), archive: ref.watch(backupArchiveProvider)),
);

/// O que as telas de backup mostram.
@immutable
final class BackupState {
  const BackupState({this.lastBackup, this.restoreOffer, this.canUndoRestore = false});

  /// O `ultimo.bipa`: "Último backup — hoje, 08:40" nos Ajustes.
  final BackupInfo? lastBackup;

  /// A oferta de restaurar no celular novo (Início), ou `null`.
  final BackupInfo? restoreOffer;

  /// Se o "Desfazer" do aviso de restauração ainda vale.
  final bool canUndoRestore;

  BackupState copyWith({BackupInfo? lastBackup, bool clearOffer = false, bool? canUndoRestore}) => BackupState(
    lastBackup: lastBackup ?? this.lastBackup,
    restoreOffer: clearOffer ? null : restoreOffer,
    canUndoRestore: canUndoRestore ?? this.canUndoRestore,
  );
}

/// O backup e a restauração (ADR 0023, seção 5), para os Ajustes e o
/// Início. As operações rodam uma de cada vez.
final backupProvider = AsyncNotifierProvider<BackupController, BackupState>(BackupController.new);

class BackupController extends AsyncNotifier<BackupState> {
  /// A operação em andamento; a próxima espera por ela.
  Future<void> _running = Future.value();
  var _busy = false;
  Timer? _undoTimer;

  @override
  Future<BackupState> build() async {
    ref.onDispose(() => _undoTimer?.cancel());
    return BackupState(lastBackup: await ref.read(readLatestBackupProvider)(), restoreOffer: await _offer());
  }

  /// O `ultimo.bipa` mais recente, ou `null`.
  BackupInfo? get lastBackupInfo => state.value?.lastBackup;

  /// O backup a oferecer no celular novo, ou `null`.
  BackupInfo? get pendingRestoreOffer => state.value?.restoreOffer;

  /// "Fazer backup agora". Devolve `null` quando o `ultimo.bipa` veio de
  /// outro aparelho e o banco está vazio (veja [CreateBackup]).
  Future<BackupInfo?> createBackup() => _serial(() async {
    final info = await ref.read(createBackupProvider)();
    if (info != null) await _update((current) => current.copyWith(lastBackup: info));
    return info;
  });

  /// O backup diário, na primeira abertura do app no dia (e ao voltar para
  /// ele). Não faz nada se outra operação está em andamento, e uma falha
  /// fica só no log: a pessoa não pediu nada.
  Future<void> runDailyBackup() async {
    if (_busy) return;
    try {
      await _serial(() async {
        final info = await ref.read(createBackupProvider)(trigger: BackupTrigger.daily);
        if (info != null) await _update((current) => current.copyWith(lastBackup: info));
      });
    } on Exception catch (error) {
      debugPrint('Backup diário falhou: $error');
    }
  }

  /// "Salvar uma cópia…": um backup novo em [destination] (o arquivo que a
  /// pessoa escolheu no "Salvar como" do Android), que também passa a ser o
  /// `ultimo.bipa`. O nome sugerido vem de [backupFileName].
  Future<BackupManifest> saveCopy(StreamConsumer<List<int>> destination) => _serial(() async {
    final manifest = await ref.read(createBackupProvider).saveCopy(destination);
    final latest = await ref.read(readLatestBackupProvider)();
    await _update((current) => current.copyWith(lastBackup: latest));
    return manifest;
  });

  /// "Conferindo o arquivo": confere o backup em [file] sem mudar nada.
  Future<PreparedRestore> prepareRestore(File file) =>
      _serial(() => ref.read(restoreBackupProvider).prepare(file.path));

  /// [prepareRestore] para um arquivo que o seletor entrega como bytes.
  Future<PreparedRestore> prepareRestoreBytes(Stream<List<int>> bytes) =>
      _serial(() => ref.read(restoreBackupProvider).prepareBytes(bytes));

  /// "Cancelar" na folha de restauração.
  Future<void> cancelRestore(PreparedRestore prepared) =>
      _serial(() => ref.read(restoreBackupProvider).cancel(prepared));

  /// "Substituir pelo backup": troca os dados e abre o prazo do "Desfazer".
  Future<void> applyRestore(PreparedRestore prepared) => _serial(() async {
    final restore = ref.read(restoreBackupProvider);
    await restore.apply(prepared);
    _undoTimer?.cancel();
    _undoTimer = Timer(ref.read(restoreUndoWindowProvider), () => unawaited(_closeUndo()));
    await _refresh(canUndoRestore: true);
  });

  /// Confere e restaura [file] de uma vez (sem a folha no meio).
  Future<void> restore(File file) async => applyRestore(await prepareRestore(file));

  /// "Desfazer": volta os dados de antes da restauração. Devolve `false` se
  /// o prazo já passou.
  Future<bool> undoRestore() => _serial(() async {
    _undoTimer?.cancel();
    final undone = await ref.read(restoreBackupProvider).undo();
    await _refresh(canUndoRestore: false);
    return undone;
  });

  /// "Começar do zero": a oferta do celular novo some.
  Future<void> dismissRestoreOffer() => _serial(() async {
    final offer = pendingRestoreOffer;
    if (offer != null) await ref.read(restoreOfferProvider).dismiss(offer);
    await _update((current) => current.copyWith(clearOffer: true));
  });

  Future<void> _closeUndo() => _serial(() async {
    await ref.read(restoreBackupProvider).discardUndo();
    await _update((current) => current.copyWith(canUndoRestore: false));
  });

  Future<BackupInfo?> _offer() => ref.read(restoreOfferProvider)();

  Future<void> _refresh({required bool canUndoRestore}) async {
    state = AsyncData(
      BackupState(
        lastBackup: await ref.read(readLatestBackupProvider)(),
        restoreOffer: await _offer(),
        canUndoRestore: canUndoRestore,
      ),
    );
  }

  Future<void> _update(BackupState Function(BackupState current) change) async {
    final current = state.value ?? await future;
    state = AsyncData(change(current));
  }

  Future<T> _serial<T>(Future<T> Function() operation) {
    final result = _running.then((_) async {
      _busy = true;
      try {
        return await operation();
      } finally {
        _busy = false;
      }
    });
    _running = result.then<void>((_) {}, onError: (_) {});
    return result;
  }
}

/// O nome sugerido no "Salvar como": `bipa-2026-10-12.bipa`.
String backupFileName(DateTime createdAt) {
  final day = createdAt.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return 'bipa-${day.year}-${two(day.month)}-${two(day.day)}.bipa';
}
