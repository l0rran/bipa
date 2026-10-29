import 'package:bipa/core/design_system/bipa_metrics.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/design_system/bipa_typography.dart';
import 'package:flutter/material.dart';

/// O nome de um grupo dentro de uma lista, em versalete, com a contagem à
/// direita: o cabeçalho de corredor da ShoppingList (`.bipa-list__aisle`),
/// usado para os locais em "Arrumar o que entrou".
class GroupLabel extends StatelessWidget {
  const GroupLabel({required this.title, required this.count, required this.semanticsLabel, super.key});

  final String title;
  final int count;

  /// O grupo por extenso: "Despensa, 4 produtos".
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = BipaText.caption.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: 12 * 0.04,
      color: colors.inkMuted,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Semantics(
      header: true,
      label: semanticsLabel,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(BipaSpacing.s4, BipaSpacing.s4, BipaSpacing.s4, BipaSpacing.s1),
        child: Row(
          children: [
            Expanded(child: Text(title.toUpperCase(), style: style)),
            const SizedBox(width: BipaSpacing.s2),
            Text('$count', style: style),
          ],
        ),
      ),
    );
  }
}
