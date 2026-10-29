import 'package:bipa/features/backup/domain/backup_manifest.dart';
import 'package:meta/meta.dart';

/// O backup mais recente guardado no aparelho (`ultimo.bipa`), para a tela
/// de Ajustes mostrar e compartilhar.
@immutable
final class BackupInfo {
  const BackupInfo({
    required this.path,
    required this.size,
    required this.manifest,
    required this.madeHere,
    this.setAsideAt,
  });

  /// O arquivo, para compartilhar.
  final String path;

  /// O tamanho em bytes. O Auto Backup do Android não leva mais de 25 MB.
  final int size;

  final BackupManifest manifest;

  /// `false` quando o arquivo veio de outro aparelho, pelo Auto Backup do
  /// Android numa troca de celular, e a pessoa ainda não respondeu à oferta
  /// de restaurar (`RestoreOffer`). Enquanto isso, sem prazo, o backup
  /// diário fica pausado e só "Fazer backup agora", com a confirmação, o
  /// substitui.
  final bool madeHere;

  /// Quando a pessoa deixou este backup de outro aparelho de lado ("Deixar
  /// de lado" ou "Começar do zero", decisão do mantenedor em 29/10, BK6), ou
  /// `null`. Deixado de lado, ele sai do Início, mas continua de outro
  /// aparelho: Ajustes ainda o restaura, e o backup diário só grava por cima
  /// a partir do dia seguinte.
  final DateTime? setAsideAt;

  /// De outro aparelho e ainda sem resposta: o Início o oferece.
  bool get awaitsAnswer => !madeHere && setAsideAt == null;

  DateTime get createdAt => manifest.createdAt;

  /// Quantas fotos foram junto.
  int get photoCount => manifest.photos.length;

  /// Cabe no limite do Auto Backup do Android (ADR 0023, seção 5).
  bool get fitsAndroidAutoBackup => size <= androidAutoBackupLimit;

  static const androidAutoBackupLimit = 25 * 1024 * 1024;
}
