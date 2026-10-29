import 'dart:math' as math;

import 'package:bipa/core/design_system/bipa_metrics.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/design_system/bipa_typography.dart';
import 'package:bipa/core/design_system/components/tap_target.dart';
import 'package:bipa/core/design_system/text_scale.dart';
import 'package:flutter/material.dart';

/// Cartão de produto da prateleira "Acabando": a imagem grande, o medidor no
/// canto e, se houver lista, o "+" para pôr na lista. Tocar abre o editor do
/// item, e segurar abre o produto.
class ProductCard extends StatelessWidget {
  const ProductCard({
    required this.name,
    required this.image,
    required this.gauge,
    required this.onTap,
    this.onLongPress,
    this.onToggleList,
    this.onList = false,
    this.addLabel,
    this.removeLabel,
    this.width = 116,
    super.key,
  });

  final String name;

  /// A foto ou o ícone da categoria, preenchendo a arte.
  final Widget image;
  final Widget gauge;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  /// `null` esconde o "+" (por exemplo, enquanto não há lista de compras).
  final VoidCallback? onToggleList;
  final bool onList;
  final String? addLabel;
  final String? removeLabel;
  final double width;

  static const _nameStyle = TextStyle(fontSize: 14, height: 18 / 14);

  /// A largura do cartão: com letra grande ele alarga, até uma vez e meia,
  /// para o nome ter mais letras por linha (H9).
  static double widthFor(BuildContext context, {double width = 116}) =>
      width * (1 + (MediaQuery.textScalerOf(context).scale(1) - 1) * 0.5).clamp(1.0, 1.5);

  /// A altura do cartão: a arte quadrada, o espaço e as linhas de nome, que
  /// crescem com a letra. A prateleira horizontal usa o mesmo valor.
  ///
  /// Com letra grande o nome não é cortado (H9): a prateleira passa os [names]
  /// de todos os cartões, e a altura cobre o mais comprido. Em letra normal
  /// são sempre duas linhas.
  static double heightFor(BuildContext context, {double width = 116, Iterable<String> names = const []}) {
    final cardWidth = widthFor(context, width: width);
    var lines = 2;
    if (isLargeText(context)) {
      final style = BipaText.bodyLarge.merge(_nameStyle);
      final scaler = MediaQuery.textScalerOf(context);
      final direction = Directionality.of(context);
      for (final name in names) {
        final painter = TextPainter(
          text: TextSpan(text: name, style: style),
          textScaler: scaler,
          textDirection: direction,
        )..layout(maxWidth: cardWidth);
        lines = math.max(lines, painter.computeLineMetrics().length);
        painter.dispose();
      }
    }
    return cardWidth + BipaSpacing.s2 + _nameStyle.scaledLineHeight(context, lines: lines);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final toggle = onToggleList;

    return SizedBox(
      width: widthFor(context, width: width),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Material(
              color: colors.surface,
              borderRadius: BorderRadius.circular(BipaRadius.lg),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                onLongPress: onLongPress,
                child: Stack(
                  children: [
                    Positioned.fill(child: image),
                    Positioned(
                      left: 6,
                      top: 6,
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: colors.surface, shape: BoxShape.circle),
                        child: gauge,
                      ),
                    ),
                    // O botão de 36 fica a 6 da borda; a área de toque, de 48, encosta nela.
                    if (toggle != null)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: _ListButton(
                          onList: onList,
                          onPressed: toggle,
                          label: (onList ? removeLabel : addLabel) ?? '',
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: BipaSpacing.s2),
          Text(
            name,
            // Letra grande: a prateleira reserva a altura do nome mais comprido.
            maxLines: isLargeText(context) ? null : 2,
            overflow: isLargeText(context) ? TextOverflow.visible : TextOverflow.ellipsis,
            style: BipaText.bodyLarge.merge(_nameStyle).copyWith(color: colors.ink),
          ),
        ],
      ),
    );
  }
}

class _ListButton extends StatelessWidget {
  const _ListButton({required this.onList, required this.onPressed, required this.label});

  final bool onList;
  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      toggled: onList,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: TapTarget(
        onTap: onPressed,
        child: Material(
          color: onList ? colors.ink : colors.surface,
          shape: const CircleBorder(),
          elevation: 2,
          shadowColor: colors.ink.withValues(alpha: 0.3),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox.square(
              dimension: 36,
              child: AnimatedSwitcher(
                duration: BipaMotion.base,
                switchInCurve: BipaMotion.spring,
                transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                child: Icon(
                  onList ? Icons.check_rounded : Icons.add_rounded,
                  key: ValueKey(onList),
                  size: 20,
                  color: onList ? colors.surface : colors.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
