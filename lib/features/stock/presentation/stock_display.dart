import 'package:bipa/core/design_system/components/stock_gauge.dart';
import 'package:bipa/core/formatting/formatters.dart';
import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/features/stock/domain/stock_item.dart';
import 'package:bipa/features/stock/domain/stock_location.dart';
import 'package:flutter/material.dart';

/// Converte o estoque do domínio para o que os componentes desenham.
extension StockItemDisplay on StockItem {
  GaugeState get gaugeState => switch (level) {
    StockLevel.ok => GaugeState.full,
    StockLevel.low => GaugeState.low,
    StockLevel.out => GaugeState.empty,
  };

  String get quantityLabel => Formatters.quantity(quantity);

  /// O estado por extenso, para o leitor de tela: "Acabou", "2 de 4 un", "3 un".
  String levelDescription(AppLocalizations l10n) {
    final unit = l10n.unitPackagesSpoken;
    final target = targetQuantity;
    return switch (level) {
      StockLevel.out => l10n.stockLevelOut,
      StockLevel.low when target != null => l10n.stockLevelLow(quantityLabel, Formatters.quantity(target), unit),
      _ => l10n.stockLevelOk(quantityLabel, unit),
    };
  }

  StockGauge gauge(AppLocalizations l10n, {double size = 40}) => StockGauge(
    quantityLabel: quantityLabel,
    state: gaugeState,
    fraction: fillFraction,
    semanticsLabel: levelDescription(l10n),
    size: size,
  );
}

extension StockLocationDisplay on StockLocation {
  IconData get icon => switch (this) {
    StockLocation.pantry => Icons.shelves,
    StockLocation.fridge => Icons.kitchen_outlined,
    StockLocation.freezer => Icons.ac_unit_rounded,
    StockLocation.bathroom => Icons.bathtub_outlined,
    StockLocation.cleaning => Icons.local_laundry_service_outlined,
    StockLocation.other => Icons.inventory_2_outlined,
  };

  String localizedLabel(AppLocalizations l10n) => switch (this) {
    StockLocation.pantry => l10n.placePantry,
    StockLocation.fridge => l10n.placeFridge,
    StockLocation.freezer => l10n.placeFreezer,
    StockLocation.bathroom => l10n.placeBathroom,
    StockLocation.cleaning => l10n.placeCleaning,
    StockLocation.other => l10n.placeOther,
  };
}
