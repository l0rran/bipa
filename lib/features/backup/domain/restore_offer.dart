import 'package:bipa/features/backup/domain/backup_info.dart';
import 'package:bipa/features/backup/domain/backup_ports.dart';
import 'package:bipa/features/backup/domain/read_latest_backup.dart';

/// A oferta de restaurar o backup de outro celular (protótipos
/// InicioBackupEncontrado, InicioBackupPendente e AjustesBackupPendente).
///
/// Numa troca de celular, o Auto Backup do Android traz o `ultimo.bipa` do
/// aparelho antigo, e só ele (ADR 0023, lacuna B1). Enquanto esse arquivo é
/// de outro aparelho e a pessoa não respondeu, ele fica restaurável, sem
/// prazo, mesmo com a casa já em uso (decisão do mantenedor em 29/10, BK1):
/// o Início mostra o cartão, Ajustes restaura pela linha do último backup, e
/// o backup diário não grava por cima ([CreateBackup]).
///
/// A resposta é restaurar ([RestoreBackup.apply]), gravar por cima com a
/// confirmação ([CreateBackup.call] com `replacePending`) ou deixar de lado
/// ([dismiss]).
final class RestoreOffer {
  const RestoreOffer({required BackupStorage storage, required BackupArchive archive})
    : _storage = storage,
      _archive = archive;

  final BackupStorage _storage;
  final BackupArchive _archive;

  /// O backup a oferecer, ou `null` se não há oferta.
  Future<BackupInfo?> call() async => pendingOf(await ReadLatestBackup(storage: _storage, archive: _archive)());

  /// [latest], se ele é de outro aparelho e espera resposta; senão `null`.
  static BackupInfo? pendingOf(BackupInfo? latest) => latest != null && !latest.madeHere ? latest : null;

  /// "Começar do zero" ou "Deixar de lado": a oferta some e o arquivo passa
  /// a ser deste aparelho. O backup diário volta e, no próximo, grava por
  /// cima dele.
  Future<void> dismiss(BackupInfo offer) => _storage.adoptLatest(offer.manifest.id);
}
