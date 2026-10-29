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
/// * enquanto ele veio de outro aparelho e a pessoa não respondeu
///   ([BackupInfo.madeHere], decisão do mantenedor em 29/10, BK1): o diário
///   fica pausado, sem prazo; "Fazer backup agora" só grava por cima com a
///   confirmação ("Apagar o backup do outro celular?", `replacePending`) e
///   com algo para guardar; e "Salvar uma cópia…" grava só a cópia. Depois
///   de "Deixar de lado" ([BackupInfo.setAsideAt]), o diário volta a gravar
///   por cima a partir do dia seguinte (BK6).
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
  /// ele não foi substituído (veja a classe). [replacePending] é a resposta
  /// "Apagar e fazer backup": o backup de outro aparelho que esperava
  /// resposta dá lugar ao deste.
  Future<BackupInfo?> call({BackupTrigger trigger = BackupTrigger.manual, bool replacePending = false}) async {
    final latest = await ReadLatestBackup(storage: _storage, archive: _archive)();
    final pending = latest != null && !latest.madeHere;
    if (trigger == BackupTrigger.daily) {
      final now = _clock();
      if (await _database.isEmpty()) return null;
      if (pending && !_setAsideBefore(latest, now)) return null;
      if (latest != null && _sameDay(latest.createdAt, now)) return null;
    } else if (pending && !replacePending) {
      return null;
    }
    return _build(trigger: trigger, pending: pending);
  }

  /// "Salvar uma cópia…": grava um backup novo em [destination] (o arquivo
  /// que a pessoa escolheu no seletor do Android) e devolve o manifesto. O
  /// mesmo arquivo passa a ser o `ultimo.bipa`, a não ser que ele seja de
  /// outro aparelho e espere resposta: aí só a cópia é gravada.
  Future<BackupManifest> saveCopy(StreamConsumer<List<int>> destination) async {
    final latest = await ReadLatestBackup(storage: _storage, archive: _archive)();
    late BackupManifest manifest;
    await _build(
      trigger: BackupTrigger.manual,
      pending: latest != null && !latest.madeHere,
      copyOnly: latest != null && !latest.madeHere,
      beforePublish: (archivePath, built) async {
        manifest = built;
        await _storage.copyTo(archivePath, destination);
      },
    );
    return manifest;
  }

  Future<BackupInfo?> _build({
    required BackupTrigger trigger,
    required bool pending,
    bool copyOnly = false,
    Future<void> Function(String archivePath, BackupManifest manifest)? beforePublish,
  }) async {
    final workspace = await _storage.createWorkspace();
    try {
      await _database.copyTo(workspace.databasePath);
      final contents = await _database.describe(workspace.databasePath);
      // Um banco vazio não toma o lugar do backup de outro aparelho, nem
      // com a confirmação: não há o que guardar.
      final publish = !copyOnly && ((trigger == BackupTrigger.manual && !pending) || !contents.isEmpty);
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

  /// O backup de outro aparelho foi deixado de lado num dia antes de [now]:
  /// o diário já pode gravar por cima (BK6).
  static bool _setAsideBefore(BackupInfo latest, DateTime now) {
    final setAside = latest.setAsideAt;
    return setAside != null && setAside.isBefore(now) && !_sameDay(setAside, now);
  }

  static bool _sameDay(DateTime a, DateTime b) {
    final (x, y) = (a.toLocal(), b.toLocal());
    return x.year == y.year && x.month == y.month && x.day == y.day;
  }
}
