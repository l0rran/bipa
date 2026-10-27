/// Base para erros de regra de negócio.
///
/// A [message] é escrita para ser exibida diretamente ao usuário.
abstract class DomainException implements Exception {
  const DomainException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}
