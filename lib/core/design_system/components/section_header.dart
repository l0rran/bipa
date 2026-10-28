import 'package:bipa/core/design_system/bipa_metrics.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/design_system/bipa_typography.dart';
import 'package:flutter/material.dart';

/// Título de seção com o selo de contagem e o "Ver tudo" opcional.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    this.count,
    this.alert = false,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final int? count;

  /// Selo em coral, para seções de alerta como "Acabando".
  final bool alert;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final count = this.count;
    final actionLabel = this.actionLabel;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: BipaSpacing.s1),
      child: Row(
        children: [
          Semantics(
            header: true,
            child: Text(title, style: BipaText.title.copyWith(color: colors.ink)),
          ),
          if (count != null) ...[
            const SizedBox(width: BipaSpacing.s2),
            Container(
              constraints: const BoxConstraints(minWidth: 26),
              height: 26,
              padding: const EdgeInsets.symmetric(horizontal: BipaSpacing.s2),
              alignment: Alignment.center,
              decoration: ShapeDecoration(
                shape: const StadiumBorder(),
                color: alert ? colors.alertSoft : colors.surfaceSunken,
              ),
              child: Text(
                '$count',
                style: BipaText.label.copyWith(fontSize: 13, color: alert ? colors.alertText : colors.ink),
              ),
            ),
          ],
          const Spacer(),
          if (actionLabel != null && onAction != null) TextButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}
