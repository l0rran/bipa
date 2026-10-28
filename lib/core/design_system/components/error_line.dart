import 'package:bipa/core/design_system/bipa_metrics.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/design_system/bipa_typography.dart';
import 'package:flutter/material.dart';

/// Uma mensagem de erro dentro de uma folha ou formulário. O design system
/// pede `alertText` sempre com ícone e mensagem: a cor sozinha não diz que é
/// um erro, e o coral de erro não se confunde com o do "ter sempre".
class ErrorLine extends StatelessWidget {
  const ErrorLine(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, size: 20, color: colors.alertText),
          const SizedBox(width: BipaSpacing.s2),
          Expanded(child: Text(message, style: BipaText.label.copyWith(color: colors.alertText))),
        ],
      ),
    );
  }
}
