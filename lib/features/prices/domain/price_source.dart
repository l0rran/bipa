/// Origem de uma observação de preço.
///
/// Na sincronização comunitária, a origem define o peso da informação:
/// cupom fiscal é verificável, etiqueta é confiável, digitação manual menos.
enum PriceSource {
  manual('Digitado'),
  priceTag('Etiqueta'),
  receipt('Cupom fiscal');

  const PriceSource(this.label);

  final String label;
}
