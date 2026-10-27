import 'package:bipa/core/design_system/bipa_metrics.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/design_system/bipa_typography.dart';
import 'package:flutter/material.dart';

/// Cartão de produto da prateleira "Acabando": a imagem grande, o medidor no
/// canto e, se houver lista, o "+" para pôr na lista. Tocar abre o produto.
class ProductCard extends StatelessWidget {
  const ProductCard({
    required this.name,
    required this.image,
    required this.gauge,
    required this.onTap,
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

  /// `null` esconde o "+" (por exemplo, enquanto não há lista de compras).
  final VoidCallback? onToggleList;
  final bool onList;
  final String? addLabel;
  final String? removeLabel;
  final double width;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final toggle = onToggleList;

    return SizedBox(
      width: width,
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
                    if (toggle != null)
                      Positioned(
                        right: 6,
                        bottom: 6,
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
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: BipaText.bodyLarge.copyWith(fontSize: 14, height: 18 / 14, color: colors.ink),
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
    );
  }
}
