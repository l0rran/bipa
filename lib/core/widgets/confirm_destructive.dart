import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Pede confirmação de uma ação que apaga ou descarta algo. Devolve `true`
/// só quando a pessoa confirma.
///
/// A confirmação usa o botão neutro, em `ink`, nunca o amarelo da marca: o
/// amarelo é de "Salvar" e de bipar, e não pode chamar para apagar (guia do
/// Button). O rótulo diz verbo e objeto ("Apagar mercado").
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  String? cancelLabel,
}) async {
  final l10n = AppLocalizations.of(context);
  final colors = context.colors;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(cancelLabel ?? l10n.cancel)),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: colors.ink, foregroundColor: colors.surface),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
