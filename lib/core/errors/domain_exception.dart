/// O que deu errado numa regra de negócio. O domínio não conhece texto de
/// interface: a camada de apresentação traduz cada código pelo ARB
/// (`domainErrorText`).
enum DomainErrorCode {
  invalidPrice,
  missingProductName,
  productNotFound,
  missingPackageProduct,
  scaleBarcode,
  invalidPackageSize,
  packageNotFound,

  /// A embalagem está no carrinho da compra em andamento (ADR 0022).
  packageInOpenTrip,

  /// `args`: o código de barras e o nome do produto que já o tem.
  duplicateBarcode,

  /// O arquivo escolhido não é um backup `.bipa` (ADR 0023).
  backupNotRecognized,

  /// O backup está danificado: um hash, a integridade do banco ou uma regra
  /// dos dados não confere. Nada foi trocado.
  backupDamaged,

  /// O backup foi feito por uma versão mais nova do app.
  backupFromNewerApp,
}

/// Base para erros de regra de negócio.
///
/// Carrega um [code] (e os [args] que o texto precisa); quem mostra o erro ao
/// usuário é a interface, pelo ARB.
abstract class DomainException implements Exception {
  const DomainException(this.code, {this.args = const []});

  final DomainErrorCode code;
  final List<String> args;

  @override
  String toString() => '$runtimeType: $code $args';
}
