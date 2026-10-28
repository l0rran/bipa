import 'package:bipa/core/design_system/bipa_metrics.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/design_system/bipa_typography.dart';
import 'package:flutter/material.dart';

/// Uma opção do menu do bipar.
typedef ScanMenuItem<T> = ({T value, IconData icon, String label, String? hint});

/// O menu do bipar (protótipo "Menu do bipar"): segurar o botão de bipar
/// abre pílulas empilhadas acima dele, sobre a tela escurecida, e o botão
/// vira um "×". Devolve o valor escolhido, ou `null` ao fechar.
Future<T?> showScanMenu<T>(
  BuildContext context, {
  required List<ScanMenuItem<T>> items,
  required String closeLabel,
}) {
  final colors = context.colors;
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: closeLabel,
    barrierColor: colors.scrim,
    transitionDuration: BipaMotion.base,
    pageBuilder: (context, _, _) => _ScanMenu(items: items, closeLabel: closeLabel),
    transitionBuilder: (context, animation, _, child) => FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(animation),
        child: child,
      ),
    ),
  );
}

class _ScanMenu<T> extends StatelessWidget {
  const _ScanMenu({required this.items, required this.closeLabel});

  final List<ScanMenuItem<T>> items;
  final String closeLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // As pílulas ficam logo acima do botão de bipar, e o "×" no lugar dele: a
    // mesma margem de baixo da barra (ScanNavBar).
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (:value, :icon, :label, :hint) in items) ...[
              Material(
                color: colors.surface,
                shape: const StadiumBorder(),
                elevation: 6,
                shadowColor: colors.ink.withValues(alpha: 0.3),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: () => Navigator.of(context).pop(value),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 52),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: BipaSpacing.s6, vertical: BipaSpacing.s3),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 22, color: colors.ink),
                          const SizedBox(width: BipaSpacing.s3),
                          Text(label, style: BipaText.bodyLarge.copyWith(fontWeight: FontWeight.w700, color: colors.ink)),
                          if (hint != null) ...[
                            const SizedBox(width: BipaSpacing.s3),
                            Text(hint, style: BipaText.body.copyWith(fontSize: 13, color: colors.inkMuted)),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: BipaSpacing.s3),
            ],
            const SizedBox(height: BipaSpacing.s2),
            // O "×" no lugar do botão de bipar.
            Material(
              color: colors.brand,
              shape: const CircleBorder(),
              elevation: 4,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => Navigator.of(context).pop(),
                child: SizedBox.square(
                  dimension: 64,
                  child: Icon(Icons.close_rounded, size: 30, color: colors.onBrand, semanticLabel: closeLabel),
                ),
              ),
            ),
            // A barra tem 72 + 22 de altura, com o botão de 64 no topo.
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
