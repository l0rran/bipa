import 'package:bipa/features/backup/domain/backup_exception.dart';
import 'package:bipa/features/backup/domain/backup_info.dart';
import 'package:bipa/features/backup/domain/backup_ports.dart';

/// O backup mais recente guardado no aparelho, ou `null` se não há um que
/// se leia.
final class ReadLatestBackup {
  const ReadLatestBackup({required BackupStorage storage, required BackupArchive archive})
    : _storage = storage,
      _archive = archive;

  final BackupStorage _storage;
  final BackupArchive _archive;

  Future<BackupInfo?> call() async {
    final latest = await _storage.latest();
    if (latest == null) return null;
    try {
      final manifest = await _archive.readManifest(latest.path);
      return BackupInfo(
        path: latest.path,
        size: latest.size,
        manifest: manifest,
        madeHere: latest.madeHereId == manifest.id,
      );
    } on BackupException {
      // Um `ultimo.bipa` que não se lê não serve para restaurar: é como se
      // não houvesse, e o próximo backup o substitui.
      return null;
    }
  }
}
