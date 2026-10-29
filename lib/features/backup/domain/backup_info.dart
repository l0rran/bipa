import 'package:bipa/features/backup/domain/backup_manifest.dart';
import 'package:meta/meta.dart';

/// O backup mais recente guardado no aparelho (`ultimo.bipa`), para a tela
/// de Ajustes mostrar e compartilhar.
@immutable
final class BackupInfo {
  const BackupInfo({required this.path, required this.size, required this.manifest, required this.madeHere});

  /// O arquivo, para compartilhar.
  final String path;

  /// O tamanho em bytes. O Auto Backup do Android não leva mais de 25 MB.
  final int size;

  final BackupManifest manifest;

  /// `false` quando o arquivo veio de outro aparelho, pelo Auto Backup do
  /// Android numa troca de celular, e a pessoa ainda não respondeu à oferta
  /// de restaurar (`RestoreOffer`). Enquanto isso, o backup diário não o
  /// substitui.
  final bool madeHere;

  DateTime get createdAt => manifest.createdAt;

  /// Quantas fotos foram junto.
  int get photoCount => manifest.photos.length;

  /// Cabe no limite do Auto Backup do Android (ADR 0023, seção 5).
  bool get fitsAndroidAutoBackup => size <= androidAutoBackupLimit;

  static const androidAutoBackupLimit = 25 * 1024 * 1024;
}
