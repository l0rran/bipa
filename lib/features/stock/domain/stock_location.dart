/// Onde o item fica guardado em casa.
enum StockLocation {
  pantry('Despensa'),
  fridge('Geladeira'),
  freezer('Freezer'),
  other('Outro');

  const StockLocation(this.label);

  final String label;
}
