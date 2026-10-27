import 'dart:io';

import 'package:bipa/core/design_system/bipa_metrics.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:flutter/material.dart';

/// Miniatura do produto: a foto, quando existe, ou o ícone da categoria em
/// quadro neutro. O selo opcional marca "na lista".
class ProductThumb extends StatelessWidget {
  const ProductThumb({
    required this.fallbackIcon,
    this.photo,
    this.size = 44,
    this.radius = BipaRadius.md,
    this.badgeLabel,
    this.dimmed = false,
    super.key,
  });

  /// Arquivo da foto no aparelho. Sem foto (ou se ela falhar), usa o ícone.
  final File? photo;
  final IconData fallbackIcon;
  final double size;
  final double radius;

  /// Quando presente, mostra o selo de "na lista" com este rótulo acessível.
  final String? badgeLabel;

  /// Esmaece o conteúdo (item que acabou).
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final icon = Icon(fallbackIcon, size: size * 0.55, color: colors.ink);
    final pixels = (size * MediaQuery.devicePixelRatioOf(context)).round();
    final file = photo;

    final content = file == null
        ? icon
        : Image.file(
            file,
            width: size,
            height: size,
            fit: BoxFit.cover,
            cacheWidth: pixels,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => icon,
          );

    final label = badgeLabel;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surfaceSunken,
                borderRadius: BorderRadius.circular(radius),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                child: Opacity(opacity: dimmed ? 0.45 : 1, child: Center(child: content)),
              ),
            ),
          ),
          if (label != null)
            Positioned(
              right: -4,
              bottom: -4,
              child: Semantics(
                label: label,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: colors.ink,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.surface, width: 2),
                  ),
                  child: Icon(Icons.check_rounded, size: 12, color: colors.surface),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
