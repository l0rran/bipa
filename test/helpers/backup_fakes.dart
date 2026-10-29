import 'dart:async';
import 'dart:io';

import 'package:bipa/features/backup/domain/backup_info.dart';
import 'package:bipa/features/backup/domain/backup_manifest.dart';
import 'package:bipa/features/backup/domain/backup_ports.dart';
import 'package:bipa/features/backup/domain/restore_backup.dart';
import 'package:bipa/features/backup/presentation/backup_files.dart';
import 'package:bipa/features/backup/presentation/backup_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Um manifesto de backup feito em [createdAt], com os números de [summary].
BackupManifest fakeManifest({
  required DateTime createdAt,
  String id = 'b1',
  BackupSummary summary = const BackupSummary(products: 214, prices: 1380, itemsAtHome: 56),
}) => BackupManifest(
  id: id,
  createdAt: createdAt,
  appVersion: '0.1.0+1',
  schemaVersion: 14,
  counts: const {},
  summary: summary,
  database: BackupEntry(path: BackupManifest.databaseEntry, sha256: '0' * 64, size: 1),
  photos: const [],
);

/// O `ultimo.bipa` de um backup feito em [createdAt].
BackupInfo fakeBackupInfo({
  required DateTime createdAt,
  String id = 'b1',
  int size = 4 * 1024 * 1024,
  bool madeHere = true,
  BackupSummary summary = const BackupSummary(products: 214, prices: 1380, itemsAtHome: 56),
}) => BackupInfo(
  path: 'ultimo.bipa',
  size: size,
  manifest: fakeManifest(createdAt: createdAt, id: id, summary: summary),
  madeHere: madeHere,
);

/// Um backup conferido, pronto para a folha de confirmação.
PreparedRestore fakePrepared({
  required DateTime createdAt,
  BackupSummary current = const BackupSummary(products: 230, prices: 1452, itemsAtHome: 60),
  bool currentIsEmpty = false,
  int adjustedItems = 0,
}) => PreparedRestore(
  manifest: fakeManifest(createdAt: createdAt),
  backup: const BackupSummary(products: 214, prices: 1380, itemsAtHome: 56),
  current: current,
  currentIsEmpty: currentIsEmpty,
  workspace: const RestoreWorkspace(path: 'novo', databasePath: 'novo/bipa.sqlite', photosPath: 'novo/fotos'),
  adjustedItems: adjustedItems,
);

/// O `backupProvider` sem arquivos: começa em [initial] e anota o que a tela
/// pediu. [onCreate], [onSaveCopy], [onPrepare], [onApply] e [onUndo] trocam
/// o que cada operação faz.
class FakeBackupController extends BackupController {
  FakeBackupController({
    this.initial = const BackupState(),
    this.onCreate,
    this.onPrepare,
    this.onApply,
    this.onUndo,
    this.onSaveCopy,
  });

  final BackupState initial;
  final Future<BackupInfo?> Function()? onCreate;
  final Future<PreparedRestore> Function()? onPrepare;
  final Future<void> Function(PreparedRestore prepared)? onApply;
  final Future<bool> Function()? onUndo;
  final Future<BackupManifest> Function(StreamConsumer<List<int>> destination)? onSaveCopy;

  final calls = <String>[];

  @override
  Future<BackupState> build() async => initial;

  @override
  Future<BackupInfo?> createBackup() async {
    calls.add('create');
    final info = await (onCreate ?? () async => null)();
    final current = state.value ?? initial;
    if (info != null) state = AsyncData(current.copyWith(lastBackup: info));
    return info;
  }

  @override
  Future<BackupManifest> saveCopy(StreamConsumer<List<int>> destination) async {
    calls.add('saveCopy');
    final save = onSaveCopy;
    if (save != null) return save(destination);
    await destination.close();
    return fakeManifest(createdAt: DateTime(2026, 10, 29, 8, 40));
  }

  @override
  Future<PreparedRestore> prepareRestore(File file) async {
    calls.add('prepare');
    return (onPrepare ?? () async => fakePrepared(createdAt: DateTime(2026, 10, 12, 21)))();
  }

  @override
  Future<void> cancelRestore(PreparedRestore prepared) async => calls.add('cancel');

  @override
  Future<void> applyRestore(PreparedRestore prepared) async {
    calls.add('apply');
    await onApply?.call(prepared);
    state = AsyncData((state.value ?? initial).copyWith(clearOffer: true, canUndoRestore: true));
  }

  @override
  Future<bool> undoRestore() async {
    calls.add('undo');
    return (onUndo ?? () async => true)();
  }

  /// Quantas vezes a reserva do "Desfazer" foi descartada (o aviso saiu sem
  /// o "Desfazer"). Fora de [calls], para não mudar o que os testes já
  /// conferem.
  var discarded = 0;

  @override
  Future<void> discardRestoreUndo(int epoch) async {
    discarded++;
    state = AsyncData((state.value ?? initial).copyWith(canUndoRestore: false));
  }

  @override
  Future<void> dismissRestoreOffer([BackupInfo? offer]) async {
    calls.add('dismiss');
    state = AsyncData((state.value ?? initial).copyWith(clearOffer: true));
  }
}

/// O seletor de arquivos do Android, sem Android: "Salvar como" grava em
/// memória com o nome pedido, e "Abrir" devolve [picked].
final class FakeBackupFiles implements BackupFiles {
  FakeBackupFiles({this.saveAnswer = true, this.picked});

  /// `false` faz de conta que a pessoa voltou sem escolher onde salvar.
  final bool saveAnswer;

  /// O arquivo escolhido em "Abrir"; `null` é voltar sem escolher.
  PickedBackup? picked;

  /// Os nomes sugeridos no "Salvar como".
  final savedNames = <String>[];
  final saved = <List<int>>[];
  var picks = 0;
  var storeOpened = 0;

  @override
  Future<bool> save(Future<String> Function(StreamConsumer<List<int>> destination) write) async {
    final sink = _MemorySink();
    savedNames.add(await write(sink));
    saved.add(sink.bytes);
    return saveAnswer;
  }

  @override
  Future<PickedBackup?> pick() async {
    picks++;
    return picked;
  }

  @override
  Future<void> openStorePage() async => storeOpened++;
}

final class _MemorySink implements StreamConsumer<List<int>> {
  final bytes = <int>[];

  @override
  Future<void> addStream(Stream<List<int>> stream) => stream.forEach(bytes.addAll);

  @override
  Future<void> close() async {}
}
