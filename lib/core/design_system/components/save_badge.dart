import 'package:bipa/core/design_system/bipa_metrics.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/design_system/bipa_typography.dart';
import 'package:flutter/material.dart';

/// O selo verde de economia (badge "save" do design system): "Mais barato
/// aqui · −R$ 1,20", "R$ 6,20 a menos que no Centro". O verde é só para o
/// que a pessoa economizou.
class SaveBadge extends StatelessWidget {
  const SaveBadge({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: ShapeDecoration(color: colors.positiveSoft, shape: const StadiumBorder()),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: BipaSpacing.s3, vertical: BipaSpacing.s2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.trending_down_rounded, size: 18, color: colors.positiveText),
            const SizedBox(width: BipaSpacing.s2),
            Flexible(
              child: Text(label, style: BipaText.label.copyWith(color: colors.positiveText)),
            ),
          ],
        ),
      ),
    );
  }
}
