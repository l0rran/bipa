/// Unidade em que o tamanho da embalagem de um produto é expresso.
enum MeasureUnit {
  unit('un'),
  gram('g'),
  kilogram('kg'),
  milliliter('ml'),
  liter('L');

  const MeasureUnit(this.symbol);

  /// O símbolo, igual em qualquer idioma: "kg", "L". O nome por extenso
  /// fica no ARB (`MeasureUnitLabel`).
  final String symbol;

  /// Unidade usada para comparar preços entre embalagens de tamanhos
  /// diferentes (R$/kg, R$/L ou R$/un).
  MeasureUnit get baseUnit => switch (this) {
    MeasureUnit.gram || MeasureUnit.kilogram => MeasureUnit.kilogram,
    MeasureUnit.milliliter || MeasureUnit.liter => MeasureUnit.liter,
    MeasureUnit.unit => MeasureUnit.unit,
  };

  /// Fator que converte uma quantidade nesta unidade para [baseUnit].
  double get toBaseFactor => switch (this) {
    MeasureUnit.gram || MeasureUnit.milliliter => 0.001,
    MeasureUnit.kilogram || MeasureUnit.liter || MeasureUnit.unit => 1.0,
  };
}
