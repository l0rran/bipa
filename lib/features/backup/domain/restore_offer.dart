import 'package:bipa/core/time/clock.dart';
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
  const RestoreOffer({required BackupStorage storage, required BackupArchive archive, required Clock clock})
    : _storage = storage,
      _archive = archive,
      _clock = clock;

  final BackupStorage _storage;
  final BackupArchive _archive;
  final Clock _clock;

  /// O backup a oferecer, ou `null` se não há oferta.
  Future<BackupInfo?> call() async => pendingOf(await ReadLatestBackup(storage: _storage, archive: _archive)());

  /// [latest], se ele é de outro aparelho e espera resposta; senão `null`.
  /// Deixado de lado, ele não é mais oferecido no Início, mas Ajustes ainda
  /// o restaura até o diário gravar por cima ([BackupInfo.setAsideAt]).
  static BackupInfo? pendingOf(BackupInfo? latest) => latest != null && latest.awaitsAnswer ? latest : null;

  /// "Começar do zero" ou "Deixar de lado": a oferta some do Início, mas o
  /// arquivo segue de outro aparelho até o fim do dia (decisão do
  /// mantenedor em 29/10, BK6): Ajustes ainda o restaura, e o backup diário
  /// só grava por cima a partir do dia seguinte.
  ///
  /// Só se o `ultimo.bipa` ainda é o de [offer]: enquanto o aviso com o
  /// "Desfazer" estava na tela, a pessoa pode ter gravado um backup novo
  /// ("Apagar e fazer backup"), e marcar o id antigo faria o backup deste
  /// aparelho parecer de outro (BK7).
  Future<void> dismiss(BackupInfo offer) async {
    final latest = await ReadLatestBackup(storage: _storage, archive: _archive)();
    if (latest == null || latest.manifest.id != offer.manifest.id || latest.madeHere) return;
    await _storage.setAside(offer.manifest.id, _clock());
  }
}
