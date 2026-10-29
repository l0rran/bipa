import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/core/l10n/app_localizations_pt.dart';
import 'package:bipa/features/stock/domain/stock_location.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final AppLocalizations l10n = AppLocalizationsPt();

  test('o aviso do item novo diz o local com a preposição certa', () {
    final cases = {
      StockLocation.pantry: '12 na Despensa',
      StockLocation.fridge: '12 na Geladeira',
      StockLocation.freezer: '12 no Freezer',
      StockLocation.bathroom: '12 no Banheiro',
      StockLocation.cleaning: '12 na Limpeza',
      StockLocation.other: '12 em Outros',
    };
    // Um caso por local: um local novo sem texto cairia em "Outros" calado.
    expect(cases.keys.toSet(), StockLocation.values.toSet());
    cases.forEach((location, text) {
      expect(l10n.cameraAtHomePlaced('12', location.name), text);
    });
  });
}
