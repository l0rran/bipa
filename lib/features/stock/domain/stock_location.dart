/// Onde o item fica guardado em casa. Gravado pelo nome no banco, então
/// novos valores podem ser acrescentados sem migração.
enum StockLocation {
  pantry('Despensa'),
  fridge('Geladeira'),
  freezer('Freezer'),
  bathroom('Banheiro'),
  cleaning('Limpeza'),
  other('Outro');

  const StockLocation(this.label);

  final String label;
}
