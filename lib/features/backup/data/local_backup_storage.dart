import 'dart:async';
import 'dart:io';

import 'package:bipa/core/backup/app_data_swap.dart';
import 'package:bipa/core/backup/latest_backup.dart';
import 'package:bipa/features/backup/domain/backup_ports.dart';

/// Os arquivos do backup no aparelho (ADR 0023, seção 5):
/// * o `ultimo.bipa` em [latestBackupPath], na pasta de suporte do app, e a
///   marca `ultimo.id` ao lado dele, com o id do último backup feito (ou
///   adotado) aqui. O Auto Backup do Android leva só o `ultimo.bipa`, então
///   num aparelho novo a marca não vem junto, e o app sabe que o arquivo é
///   de outro aparelho. A marca `ultimo.deixado` guarda o id e a hora em que
///   a pessoa deixou de lado o arquivo de outro aparelho (BK6);
/// * o backup é montado em `backup/trabalho/`, ao lado do `ultimo.bipa`,
///   para a troca final ser um `rename`;
/// * a restauração é preparada em `restauracao/novo/`, ao lado do banco
///   ([AppDataLocation]), e trocada pela [AppDataSwap], que guarda o banco e
///   as fotos de antes em `restauracao/reserva/` para o "Desfazer". Um
///   arquivo recebido como fluxo fica em `restauracao/recebido.bipa` até ser
///   conferido. Quando a restauração adota o `ultimo.bipa`, a marca de antes
///   fica em `restauracao/ultimo.id`, para o "Desfazer" devolvê-la (BK5).
final class LocalBackupStorage implements BackupStorage {
  LocalBackupStorage({
    required Future<AppDataLocation> Function() location,
    required Future<Directory> Function() supportDirectory,
    required Future<void> Function() closeDatabase,
    required FutureOr<void> Function() reopenDatabase,
  }) : _location = location,
       _supportDirectory = supportDirectory,
       _closeDatabase = closeDatabase,
       _reopenDatabase = reopenDatabase;

  final Future<AppDataLocation> Function() _location;
  final Future<Directory> Function() _supportDirectory;
  final Future<void> Function() _closeDatabase;
  final FutureOr<void> Function() _reopenDatabase;

  Future<File> _latestFile() => latestBackupFile(supportDirectory: _supportDirectory);

  Future<File> _madeHereMarker() async =>
      File('${(await _latestFile()).parent.path}${Platform.pathSeparator}ultimo.id');

  @override
  Future<String> photosPath() async => (await _location()).photosPath;

  @override
  Future<BackupWorkspace> createWorkspace() async {
    final work = Directory(joinPath((await _latestFile()).parent.path, 'trabalho'));
    // Sobras de um backup interrompido saem antes.
    if (await work.exists()) await work.delete(recursive: true);
    await work.create(recursive: true);
    return BackupWorkspace(
      path: work.path,
      databasePath: joinPath(work.path, 'bipa.sqlite'),
      archivePath: joinPath(work.path, 'ultimo.bipa'),
    );
  }

  @override
  Future<RestoreWorkspace> restoreWorkspace() async {
    final work = Directory(joinPath((await _location()).restoreAreaPath, 'novo'));
    if (await work.exists()) await work.delete(recursive: true);
    await work.create(recursive: true);
    return RestoreWorkspace(
      path: work.path,
      databasePath: joinPath(work.path, 'bipa.sqlite'),
      photosPath: joinPath(work.path, 'fotos'),
    );
  }

  @override
  Future<void> discard(String workspace) async {
    try {
      final entity = await FileSystemEntity.isDirectory(workspace) ? Directory(workspace) : File(workspace);
      if (await entity.exists()) await entity.delete(recursive: true);
    } on FileSystemException {
      // Sai na próxima vez que a pasta for usada, ou na próxima abertura.
    }
  }

  @override
  Future<String> receive(Stream<List<int>> bytes) async {
    final area = Directory((await _location()).restoreAreaPath);
    await area.create(recursive: true);
    final file = File(joinPath(area.path, 'recebido.bipa'));
    final sink = file.openWrite();
    try {
      await sink.addStream(bytes);
      await sink.flush();
    } finally {
      await sink.close();
    }
    return file.path;
  }

  @override
  Future<void> copyTo(String path, StreamConsumer<List<int>> destination) => File(path).openRead().pipe(destination);

  @override
  Future<LatestBackupFile?> latest() async {
    final file = await _latestFile();
    if (!await file.exists()) return null;
    final marker = await _madeHereMarker();
    final madeHereId = await marker.exists() ? (await marker.readAsString()).trim() : null;
    final (setAsideId, setAsideAt) = await _readSetAside();
    return LatestBackupFile(
      path: file.path,
      size: await file.length(),
      madeHereId: madeHereId,
      setAsideId: setAsideId,
      setAsideAt: setAsideAt,
    );
  }

  @override
  Future<LatestBackupFile> publishLatest(String archivePath, String backupId) async {
    final target = await _latestFile();
    await target.parent.create(recursive: true);
    // `rename` no mesmo volume troca o arquivo de uma vez.
    final published = await File(archivePath).rename(target.path);
    await adoptLatest(backupId);
    // O backup deixado de lado saiu do lugar: a marca dele não serve mais.
    final setAside = await _setAsideMarker();
    if (await setAside.exists()) await setAside.delete();
    return LatestBackupFile(path: published.path, size: await published.length(), madeHereId: backupId);
  }

  @override
  Future<void> adoptLatest(String backupId) => _writeAtOnce(_madeHereMarker(), backupId);

  @override
  Future<void> setAside(String backupId, DateTime at) =>
      _writeAtOnce(_setAsideMarker(), '$backupId\n${at.toUtc().toIso8601String()}');

  /// A marca `ultimo.deixado`, ao lado do `ultimo.bipa`: o id do backup de
  /// outro aparelho deixado de lado e quando, uma linha cada (BK6).
  Future<File> _setAsideMarker() async =>
      File('${(await _latestFile()).parent.path}${Platform.pathSeparator}ultimo.deixado');

  Future<(String?, DateTime?)> _readSetAside() async {
    final marker = await _setAsideMarker();
    if (!await marker.exists()) return (null, null);
    final lines = (await marker.readAsString()).trim().split('\n');
    final at = lines.length < 2 ? null : DateTime.tryParse(lines[1].trim())?.toLocal();
    // Sem a data, a marca não diz nada: o arquivo segue esperando resposta.
    return at == null ? (null, null) : (lines.first.trim(), at);
  }

  /// Grava [contents] em [file] de uma vez: quem lê vê o antigo ou o novo.
  Future<void> _writeAtOnce(Future<File> file, String contents) async {
    final target = await file;
    await target.parent.create(recursive: true);
    final temporary = File('${target.path}.novo');
    await temporary.writeAsString(contents, flush: true);
    await temporary.rename(target.path);
  }

  @override
  Future<void> replaceAppData(RestoreWorkspace workspace, {String? adopt}) async {
    final swap = AppDataSwap(await _location());
    final marker = await _madeHereMarker();
    final before = await marker.exists() ? (await marker.readAsString()).trim() : null;
    await _closeDatabase();
    try {
      await swap.replace(databasePath: workspace.databasePath, photosPath: workspace.photosPath);
    } finally {
      // Com os arquivos novos, ou com os antigos de volta se a troca falhou.
      await _reopenDatabase();
    }

    // A reserva agora é a desta restauração: a marca guardada por uma
    // restauração anterior não vale mais.
    final saved = await _markerBeforeRestore();
    if (adopt == null) {
      if (await saved.exists()) await saved.delete();
      return;
    }
    // Vazio quer dizer que não havia marca.
    await saved.writeAsString(before ?? '', flush: true);
    await adoptLatest(adopt);
  }

  @override
  Future<bool> undoReplace() async {
    final swap = AppDataSwap(await _location());
    if (!await swap.hasReserve()) return false;
    await _closeDatabase();
    final bool undone;
    try {
      undone = await swap.undo();
    } finally {
      await _reopenDatabase();
    }
    if (undone) await _returnMarker();
    return undone;
  }

  @override
  Future<void> discardReserve() async {
    await AppDataSwap(await _location()).discardReserve();
    try {
      final saved = await _markerBeforeRestore();
      if (await saved.exists()) await saved.delete();
    } on FileSystemException {
      // Sai com a área de restauração, na próxima abertura.
    }
  }

  /// A marca `ultimo.id` de antes de uma restauração que adotou o
  /// `ultimo.bipa` (BK5), para o "Desfazer" devolvê-la. Fica na área de
  /// restauração, que a abertura seguinte do app limpa junto com a reserva.
  Future<File> _markerBeforeRestore() async => File(joinPath((await _location()).restoreAreaPath, 'ultimo.id'));

  /// Devolve a marca de antes da restauração, se ela adotou o `ultimo.bipa`.
  Future<void> _returnMarker() async {
    final saved = await _markerBeforeRestore();
    if (!await saved.exists()) return;
    final before = (await saved.readAsString()).trim();
    if (before.isEmpty) {
      final marker = await _madeHereMarker();
      if (await marker.exists()) await marker.delete();
    } else {
      await adoptLatest(before);
    }
    await saved.delete();
  }
}
