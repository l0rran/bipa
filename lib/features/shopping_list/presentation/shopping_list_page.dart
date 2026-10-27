import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/core/widgets/empty_state.dart';
import 'package:flutter/material.dart';

/// Aba da lista de compras. A lista (ADR e roadmap da fase 1) ainda não existe:
/// por enquanto a aba avisa onde ver o que está acabando.
class ShoppingListPage extends StatelessWidget {
  const ShoppingListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: EmptyState(icon: Icons.checklist_rounded, message: AppLocalizations.of(context).listComingSoon),
      ),
    );
  }
}
