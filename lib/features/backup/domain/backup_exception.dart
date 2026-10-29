import 'package:bipa/core/errors/domain_exception.dart';

/// Por que um backup não pôde ser restaurado (ADR 0023, seção 5). Em todos
/// os casos, nada no aparelho mudou.
final class BackupException extends DomainException {
  /// Não é um `.bipa`: não é zip, falta o manifesto, ou ele não se lê.
  const BackupException.notRecognized([this.detail]) : super(DomainErrorCode.backupNotRecognized);

  /// O arquivo é um `.bipa`, mas algo dentro não confere: um hash, um
  /// tamanho, a integridade do banco, as chaves estrangeiras ou a soma dos
  /// lotes.
  const BackupException.damaged([this.detail]) : super(DomainErrorCode.backupDamaged);

  /// Feito por uma versão mais nova do app: um formato ou esquema que esta
  /// não conhece, ou um valor gravado que ela não lê (ADR 0023, lacuna B4).
  /// A pessoa precisa atualizar o app.
  const BackupException.fromNewerApp([this.detail]) : super(DomainErrorCode.backupFromNewerApp);

  /// O que exatamente não conferiu, para o log e os testes; não vai para a
  /// tela.
  final String? detail;

  @override
  String toString() => 'BackupException: $code${detail == null ? '' : ' ($detail)'}';
}
