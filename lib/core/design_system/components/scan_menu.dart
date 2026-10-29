import 'package:bipa/core/design_system/bipa_metrics.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/design_system/bipa_typography.dart';
import 'package:flutter/material.dart';

/// Uma opção do menu do bipar.
typedef ScanMenuItem<T> = ({T value, IconData icon, String label, String? hint});

/// O menu do bipar (protótipo "Menu do bipar"): segurar o botão de bipar
/// abre pílulas empilhadas acima dele, sobre a tela escurecida, e o botão
/// vira um "×". Devolve o valor escolhido, ou `null` ao fechar.
///
/// [anchor] é onde o botão de bipar está, em coordenadas globais (o que a
/// `ScanNavBar` passa no toque longo): o "×" fica exatamente no lugar dele, e
/// as pílulas, logo acima, alinhadas à direita quando o botão flutua à
/// direita (letra grande). Sem [anchor], o menu fica no meio, embaixo.
Future<T?> showScanMenu<T>(
  BuildContext context, {
  required List<ScanMenuItem<T>> items,
  required String closeLabel,
  Rect? anchor,
}) {
  final colors = context.colors;
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: closeLabel,
    barrierColor: colors.scrim,
    transitionDuration: BipaMotion.base,
    pageBuilder: (context, _, _) => _ScanMenu(items: items, closeLabel: closeLabel, anchor: anchor),
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
  const _ScanMenu({required this.items, required this.closeLabel, this.anchor});

  static const _openShape = RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(64 * 0.3)));

  final List<ScanMenuItem<T>> items;
  final String closeLabel;
  final Rect? anchor;

  /// As pílulas, uma embaixo da outra, cada uma com o vão de baixo.
  List<Widget> _pills(BuildContext context) {
    final colors = context.colors;
    return [
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
                    // Flexíveis: com letra grande, quebram a linha em vez de passar da tela.
                    Flexible(
                      child: Text(
                        label,
                        style: BipaText.bodyLarge.copyWith(fontWeight: FontWeight.w700, color: colors.ink),
                      ),
                    ),
                    if (hint != null) ...[
                      const SizedBox(width: BipaSpacing.s3),
                      Flexible(
                        child: Text(hint, style: BipaText.body.copyWith(fontSize: 13, color: colors.inkMuted)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: BipaSpacing.s3),
      ],
    ];
  }

  /// O "×" no lugar do botão de bipar, que aberto fica com os cantos de 30%
  /// (o `.bipa-scan.is-open` do design system).
  Widget _close(BuildContext context, double size) {
    final colors = context.colors;
    return Material(
      color: colors.brand,
      shape: _openShape,
      elevation: 4,
      child: InkWell(
        customBorder: _openShape,
        onTap: () => Navigator.of(context).pop(),
        child: SizedBox.square(
          dimension: size,
          child: Icon(Icons.close_rounded, size: 30, color: colors.onBrand, semanticLabel: closeLabel),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final anchor = this.anchor;
    if (anchor != null) return _anchored(context, anchor);
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
            ..._pills(context),
            const SizedBox(height: BipaSpacing.s2),
            _close(context, 64),
            // A barra tem 72 + 22 de altura, com o botão de 64 no topo.
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  /// O "×" exatamente sobre o botão de bipar, e as pílulas logo acima.
  Widget _anchored(BuildContext context, Rect anchor) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      // O bipar flutuante fica à direita; o da barra normal, no meio.
      final atEnd = anchor.center.dx > size.width * 2 / 3;
      return Stack(
        children: [
          Positioned(
            left: atEnd ? BipaSpacing.s3 : 0,
            right: atEnd ? size.width - anchor.right : 0,
            bottom: size.height - anchor.top + BipaSpacing.s2,
            child: Padding(
              padding: atEnd ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: BipaSpacing.s3),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: atEnd ? CrossAxisAlignment.end : CrossAxisAlignment.center,
                children: _pills(context),
              ),
            ),
          ),
          Positioned.fromRect(rect: anchor, child: _close(context, anchor.shortestSide)),
        ],
      );
    },
  );
}
