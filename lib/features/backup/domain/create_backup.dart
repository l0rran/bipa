import 'dart:async';

import 'package:bipa/core/id/id_generator.dart';
import 'package:bipa/core/time/clock.dart';
import 'package:bipa/features/backup/domain/backup_info.dart';
import 'package:bipa/features/backup/domain/backup_manifest.dart';
import 'package:bipa/features/backup/domain/backup_ports.dart';
import 'package:bipa/features/backup/domain/read_latest_backup.dart';

/// O que pediu o backup.
enum BackupTrigger {
  /// A pessoa tocou em "Fazer backup agora" ou "Salvar uma cópia…".
  manual,

  /// A primeira abertura do app no dia (decisão do mantenedor em 29/10:
  /// sem WorkManager, sem gravar ao ir para o fundo nem ao terminar compra).
  daily,
}

/// Grava o backup `.bipa` e o põe no lugar do `ultimo.bipa` (ADR 0023,
/// seção 5).
///
/// O backup é montado numa pasta de trabalho (a cópia do banco com `VACUUM
/// INTO`, depois o zip) e só no fim substitui o `ultimo.bipa`, de uma vez:
/// quem lê o arquivo, inclusive o Auto Backup do Android, vê o anterior
/// inteiro ou o novo inteiro.
///
/// O `ultimo.bipa` não é substituído:
/// * pelo backup diário, se já houve um backup hoje;
/// * pelo backup diário, com o banco vazio: um app recém-instalado não põe
///   um backup vazio no lugar do que o Auto Backup do Android trouxe, nem no
///   Google Drive;
/// * enquanto ele veio de outro aparelho e a pessoa não respondeu à oferta
///   de restaurar ([BackupInfo.madeHere]): nem pelo diário, nem por um
///   backup manual com o banco vazio.
final class CreateBackup {
  CreateBackup({
    required BackupDatabase database,
    required BackupArchive archive,
    required BackupStorage storage,
    required Future<String> Function() appVersion,
    required Clock clock,
    required IdGenerator ids,
  }) : _database = database,
       _archive = archive,
       _storage = storage,
       _appVersion = appVersion,
       _clock = clock,
       _ids = ids;

  final BackupDatabase _database;
  final BackupArchive _archive;
  final BackupStorage _storage;
  final Future<String> Function() _appVersion;
  final Clock _clock;
  final IdGenerator _ids;

  /// Grava o backup e devolve o que ficou no `ultimo.bipa`; `null` quando
  /// ele não foi substituído (veja a classe).
  Future<BackupInfo?> call({BackupTrigger trigger = BackupTrigger.manual}) async {
    final latest = await ReadLatestBackup(storage: _storage, archive: _archive)();
    if (trigger == BackupTrigger.daily) {
      if (await _database.isEmpty()) return null;
      if (latest != null && !latest.madeHere) return null;
      if (latest != null && _sameDay(latest.createdAt, _clock())) return null;
    }
    return _build(latest: latest, trigger: trigger);
  }

  /// "Salvar uma cópia…": grava um backup novo em [destination] (o arquivo
  /// que a pessoa escolheu no seletor do Android) e, pelas mesmas regras de
  /// um backup manual, também no `ultimo.bipa`. Devolve o manifesto.
  Future<BackupManifest> saveCopy(StreamConsumer<List<int>> destination) async {
    final latest = await ReadLatestBackup(storage: _storage, archive: _archive)();
    late BackupManifest manifest;
    await _build(
      latest: latest,
      trigger: BackupTrigger.manual,
      beforePublish: (archivePath, built) async {
        manifest = built;
        await _storage.copyTo(archivePath, destination);
      },
    );
    return manifest;
  }

  Future<BackupInfo?> _build({
    required BackupInfo? latest,
    required BackupTrigger trigger,
    Future<void> Function(String archivePath, BackupManifest manifest)? beforePublish,
  }) async {
    final workspace = await _storage.createWorkspace();
    try {
      await _database.copyTo(workspace.databasePath);
      final contents = await _database.describe(workspace.databasePath);
      final publish = switch (trigger) {
        BackupTrigger.daily => !contents.isEmpty,
        BackupTrigger.manual => latest == null || latest.madeHere || !contents.isEmpty,
      };
      if (!publish && beforePublish == null) return null;

      final draft = BackupDraft(
        id: _ids.newId(),
        createdAt: _clock(),
        appVersion: await _appVersion(),
        schemaVersion: _database.schemaVersion,
        counts: contents.counts,
        summary: contents.summary,
      );
      final manifest = await _archive.write(
        target: workspace.archivePath,
        draft: draft,
        databasePath: workspace.databasePath,
        photosPath: await _storage.photosPath(),
        photoPaths: contents.photoPaths,
      );
      await beforePublish?.call(workspace.archivePath, manifest);
      if (!publish) return null;
      final published = await _storage.publishLatest(workspace.archivePath, manifest.id);
      return BackupInfo(path: published.path, size: published.size, manifest: manifest, madeHere: true);
    } finally {
      await _storage.discard(workspace.path);
    }
  }

  static bool _sameDay(DateTime a, DateTime b) {
    final (x, y) = (a.toLocal(), b.toLocal());
    return x.year == y.year && x.month == y.month && x.day == y.day;
  }
}
