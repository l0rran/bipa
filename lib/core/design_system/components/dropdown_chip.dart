import 'package:bipa/core/design_system/bipa_metrics.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/design_system/bipa_typography.dart';
import 'package:bipa/core/design_system/components/tap_target.dart';
import 'package:flutter/material.dart';

/// Chip que abre uma escolha (Chip do design system, com a seta): o mercado
/// da lista, por exemplo. Para o chip sobre a câmera, veja `CameraGlassChip`.
class DropdownChip extends StatelessWidget {
  const DropdownChip({required this.icon, required this.label, required this.onTap, this.semanticsLabel, super.key});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// O que o leitor de tela ouve; sem ele, o [label].
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      label: semanticsLabel ?? label,
      excludeSemantics: true,
      onTap: onTap,
      // O chip tem 40 de altura; a área de toque, 48.
      child: TapTarget(
        onTap: onTap,
        child: Material(
          color: colors.surfaceSunken,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Container(
              height: 40,
              padding: const EdgeInsets.only(left: BipaSpacing.s2, right: BipaSpacing.s3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: colors.ink),
                  const SizedBox(width: BipaSpacing.s2),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BipaText.label.copyWith(color: colors.ink),
                    ),
                  ),
                  const SizedBox(width: BipaSpacing.s1),
                  Icon(Icons.expand_more_rounded, size: 16, color: colors.ink),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
