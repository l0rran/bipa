/// De onde vieram os dados de uma embalagem (ADR 0023, lacuna C1): da
/// pessoa ou de uma das bases do catálogo pronto (ADR 0024). A tela do
/// produto cita a fonte, e a sincronização (fase 2) sabe o que tem licença
/// de terceiros.
///
/// O nome do valor é gravado em `product_packages.origin` e faz parte do
/// formato do backup (ADR 0023, lacuna B4): renomear exige migração.
enum PackageOrigin {
  /// Cadastrada pela pessoa (ou anterior ao esquema 15).
  person,

  /// Open Food Facts: alimentos.
  openFoodFacts,

  /// Open Products Facts: limpeza e outros produtos.
  openProductsFacts,

  /// Open Beauty Facts: higiene e cosméticos.
  openBeautyFacts;

  /// Os dados vieram do catálogo, sob a ODbL (ADR 0024). Uma embalagem do
  /// catálogo que a pessoa corrigiu continua vindo dele.
  bool get fromCatalog => this != person;
}
