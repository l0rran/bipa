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

  BackupState copyWith({
    BackupInfo? lastBackup,
    BackupInfo? restoreOffer,
    bool clearOffer = false,
    bool? canUndoRestore,
  }) => BackupState(
    lastBackup: lastBackup ?? this.lastBackup,
    restoreOffer: clearOffer ? null : restoreOffer ?? this.restoreOffer,
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
  var _restoreEpoch = 0;

  @override
  Future<BackupState> build() async =>
      BackupState(lastBackup: await ref.read(readLatestBackupProvider)(), restoreOffer: await _offer());

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

  /// "Substituir pelo backup": troca os dados e guarda a reserva do
  /// "Desfazer". A reserva vale enquanto o aviso da restauração vale: quem
  /// mostra o aviso chama [discardRestoreUndo] quando ele sai sem o
  /// "Desfazer" (ou, se o app fechar antes, a abertura seguinte a apaga).
  /// Não há relógio aqui: o aviso espera a pessoa com leitor de tela, estica
  /// com o "Tempo para agir" e para com o dedo em cima (BK2).
  Future<void> applyRestore(PreparedRestore prepared) => _serial(() async {
    final restore = ref.read(restoreBackupProvider);
    await restore.apply(prepared);
    _restoreEpoch++;
    await _refresh(canUndoRestore: true);
  });

  /// Qual restauração guarda a reserva de agora. Quem mostra o aviso lê o
  /// número depois de [applyRestore] e o devolve em [discardRestoreUndo].
  int get restoreEpoch => _restoreEpoch;

  /// Confere e restaura [file] de uma vez (sem a folha no meio).
  Future<void> restore(File file) async => applyRestore(await prepareRestore(file));

  /// "Desfazer": volta os dados de antes da restauração. Devolve `false` se
  /// a reserva já não existe.
  Future<bool> undoRestore() => _serial(() async {
    final undone = await ref.read(restoreBackupProvider).undo();
    await _refresh(canUndoRestore: false);
    return undone;
  });

  /// O aviso da restauração [epoch] saiu sem o "Desfazer" (ou não havia
  /// "Desfazer" a oferecer): a reserva é descartada. Não faz nada se outra
  /// restauração já tomou o lugar dela, porque o aviso novo cobre a reserva
  /// nova. Uma falha fica só no log: a abertura seguinte a apaga.
  Future<void> discardRestoreUndo(int epoch) => _serial(() async {
    if (epoch != _restoreEpoch) return;
    try {
      await ref.read(restoreBackupProvider).discardUndo();
    } on Exception catch (error) {
      debugPrint('Descartar a reserva da restauração falhou: $error');
      return;
    }
    await _update((current) => current.copyWith(canUndoRestore: false));
  });

  /// "Começar do zero", na tela: o cartão do celular novo some na hora, mas
  /// o arquivo só é adotado em [dismissRestoreOffer], quando o aviso com
  /// "Desfazer" sai. Devolve a oferta escondida, ou `null`.
  BackupInfo? hideRestoreOffer() {
    final current = state.value;
    final offer = current?.restoreOffer;
    if (current != null && offer != null) state = AsyncData(current.copyWith(clearOffer: true));
    return offer;
  }

  /// O "Desfazer" de "Começar do zero": o cartão volta.
  void bringBackRestoreOffer(BackupInfo offer) {
    final current = state.value;
    if (current != null) state = AsyncData(current.copyWith(restoreOffer: offer));
  }

  /// "Começar do zero" valendo: adota [offer] (ou a oferta pendente), que
  /// deixa de ser oferecida, e o backup diário volta a substituí-lo.
  Future<void> dismissRestoreOffer([BackupInfo? offer]) => _serial(() async {
    final dismissed = offer ?? pendingRestoreOffer;
    if (dismissed != null) await ref.read(restoreOfferProvider).dismiss(dismissed);
    await _update((current) => current.copyWith(clearOffer: true));
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
