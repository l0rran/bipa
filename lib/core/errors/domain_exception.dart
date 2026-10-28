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

  /// `args`: o código de barras e o nome do produto que já o tem.
  duplicateBarcode,
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
