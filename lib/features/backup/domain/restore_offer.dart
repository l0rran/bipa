import 'package:bipa/features/backup/domain/backup_info.dart';
import 'package:bipa/features/backup/domain/backup_ports.dart';
import 'package:bipa/features/backup/domain/read_latest_backup.dart';

/// A oferta de restaurar no celular novo (protótipo InicioBackupEncontrado).
///
/// Numa troca de celular, o Auto Backup do Android traz o `ultimo.bipa` do
/// aparelho antigo, e só ele (ADR 0023, lacuna B1). Com o banco ainda vazio
/// e esse arquivo de outro aparelho, o Início oferece restaurá-lo. Enquanto
/// a pessoa não responde, o backup diário não grava por cima dele
/// ([CreateBackup]).
final class RestoreOffer {
  const RestoreOffer({required BackupDatabase database, required BackupStorage storage, required BackupArchive archive})
    : _database = database,
      _storage = storage,
      _archive = archive;

  final BackupDatabase _database;
  final BackupStorage _storage;
  final BackupArchive _archive;

  /// O backup a oferecer, ou `null` se não há oferta.
  Future<BackupInfo?> call() async {
    final latest = await ReadLatestBackup(storage: _storage, archive: _archive)();
    if (latest == null || latest.madeHere) return null;
    if (!await _database.isEmpty()) return null;
    return latest;
  }

  /// "Começar do zero": a oferta some. O arquivo continua lá, e dá para
  /// restaurá-lo pelos Ajustes até o próximo backup diário, que agora pode
  /// substituí-lo.
  Future<void> dismiss(BackupInfo offer) => _storage.adoptLatest(offer.manifest.id);
}
