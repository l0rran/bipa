import 'package:bipa/core/design_system/bipa_metrics.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/design_system/bipa_typography.dart';
import 'package:bipa/core/design_system/components/choice_chips.dart';
import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/features/stock/domain/stock_location.dart';
import 'package:bipa/features/stock/presentation/stock_display.dart';
import 'package:flutter/material.dart';

/// Os locais da casa como opções dos [ChoiceChips], na ordem de sempre.
List<ChoiceOption<StockLocation>> stockLocationOptions(AppLocalizations l10n) => [
  for (final location in StockLocation.values)
    ChoiceOption(value: location, label: location.localizedLabel(l10n), icon: location.icon),
];

/// A folha "Onde fica o Leite integral 1 L?" (protótipo "Guardar em casa,
/// escolher o local", AB9): os locais em chips, com [current] marcado.
/// Tocar escolhe e fecha; devolve o local tocado, ou `null` se a folha
/// fechou sem escolha. Quem chama grava.
Future<StockLocation?> pickStockLocation(
  BuildContext context, {
  required String productName,
  required StockLocation current,
}) => showModalBottomSheet<StockLocation>(
  context: context,
  showDragHandle: true,
  useSafeArea: true,
  isScrollControlled: true,
  builder: (_) => PlaceChoiceSheet(productName: productName, current: current),
);

/// O conteúdo da folha de [pickStockLocation].
class PlaceChoiceSheet extends StatelessWidget {
  const PlaceChoiceSheet({required this.productName, required this.current, super.key});

  final String productName;
  final StockLocation current;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final title = l10n.stockPlaceQuestion(productName);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(BipaSpacing.s4, 0, BipaSpacing.s4, BipaSpacing.s6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: BipaSpacing.s1),
            child: Semantics(
              header: true,
              child: Text(title, style: BipaText.title.copyWith(color: colors.ink)),
            ),
          ),
          const SizedBox(height: BipaSpacing.s3),
          ChoiceChips<StockLocation>(
            options: stockLocationOptions(l10n),
            selected: current,
            semanticsLabel: title,
            wrap: true,
            onSelected: (location) => Navigator.of(context).pop(location),
          ),
        ],
      ),
    );
  }
}
