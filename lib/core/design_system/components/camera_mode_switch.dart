import 'dart:math' as math;

import 'package:bipa/core/design_system/bipa_metrics.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/design_system/bipa_typography.dart';
import 'package:bipa/core/design_system/components/shrink_to_fit.dart';
import 'package:flutter/material.dart';

/// O seletor de modo sobre a câmera (protótipo "Captura"): "Etiqueta ·
/// Código". O escolhido fica numa pílula clara; os outros, em texto.
class CameraModeSwitch<T> extends StatelessWidget {
  const CameraModeSwitch({required this.options, required this.selected, required this.onSelected, super.key});

  final List<({T value, String label})> options;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // O espaço do rótulo em cada opção: com letra grande, as opções dividem a
    // largura e o rótulo encolhe um pouco em vez de passar da tela (H3).
    return LayoutBuilder(
      builder: (context, constraints) {
        final labelWidth = math.max(0.0, constraints.maxWidth / options.length - 2 * BipaSpacing.s6);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (:value, :label) in options)
              Semantics(
                button: true,
                selected: value == selected,
                label: label,
                excludeSemantics: true,
                onTap: () => onSelected(value),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onSelected(value),
                  child: AnimatedContainer(
                    duration: BipaMotion.base,
                    constraints: const BoxConstraints(minHeight: 48, minWidth: 64),
                    padding: const EdgeInsets.symmetric(horizontal: BipaSpacing.s6),
                    alignment: Alignment.center,
                    decoration: ShapeDecoration(
                      shape: const StadiumBorder(),
                      color: value == selected ? colors.surface : Colors.transparent,
                    ),
                    child: ShrinkToFit(
                      maxWidth: labelWidth,
                      alignment: Alignment.center,
                      child: Text(
                        label,
                        style: BipaText.label.copyWith(
                          fontSize: 15,
                          color: value == selected ? colors.ink : colors.onCamera.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
