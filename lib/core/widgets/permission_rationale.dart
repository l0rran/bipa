import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Diz para que serve uma permissão antes do pedido do sistema, no momento em
/// que ela faz sentido (Android Developers, "Request runtime permissions").
///
/// Devolve `true` em "Continuar": aí, sim, o app mostra o pedido do sistema.
/// "Agora não" segue sem a permissão, e o sistema não chega a perguntar.
Future<bool> explainPermission(BuildContext context, {required IconData icon, required String reason}) async {
  final l10n = AppLocalizations.of(context);
  final answer = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: Icon(icon),
      content: Text(reason, textAlign: TextAlign.center),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.permissionNotNow)),
        FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l10n.permissionContinue)),
      ],
    ),
  );
  return answer ?? false;
}
