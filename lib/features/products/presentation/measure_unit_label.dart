import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/features/products/domain/measure_unit.dart';

/// O nome da unidade por extenso, como o formulário do produto mostra.
extension MeasureUnitLabel on MeasureUnit {
  String localizedLabel(AppLocalizations l10n) => switch (this) {
    MeasureUnit.unit => l10n.measureUnit,
    MeasureUnit.gram => l10n.measureGram,
    MeasureUnit.kilogram => l10n.measureKilogram,
    MeasureUnit.milliliter => l10n.measureMilliliter,
    MeasureUnit.liter => l10n.measureLiter,
  };

  /// "o quilo", para o leitor de tela no lugar de "/kg".
  String spokenPer(AppLocalizations l10n) => l10n.perUnitSpoken(name);
}
