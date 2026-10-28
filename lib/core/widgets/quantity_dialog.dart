import 'package:bipa/core/design_system/components/quantity_stepper.dart';
import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Pergunta quantas embalagens, com o stepper do Início: o item do carrinho
/// ou da lista. Devolve a quantidade escolhida, ou `null` em "Cancelar".
Future<int?> showQuantityDialog(BuildContext context, {required String title, required int initial}) {
  final l10n = AppLocalizations.of(context);
  var quantity = initial < 1 ? 1 : initial;
  return showDialog<int>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(title),
        content: Center(
          heightFactor: 1,
          child: QuantityStepper(
            value: '$quantity',
            unit: l10n.unitPackages,
            decrementLabel: l10n.cartQuantityLess,
            incrementLabel: l10n.cartQuantityMore,
            onIncrement: () => setState(() => quantity++),
            onDecrement: quantity > 1 ? () => setState(() => quantity--) : null,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.of(context).pop(quantity), child: Text(l10n.save)),
        ],
      ),
    ),
  );
}
