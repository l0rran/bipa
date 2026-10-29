import 'package:bipa/core/design_system/bipa_metrics.dart';
import 'package:bipa/core/design_system/bipa_palette.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/design_system/bipa_typography.dart';
import 'package:bipa/core/money/money.dart';
import 'package:flutter/material.dart';

/// A etiqueta amarela de preço em destaque (PriceTag, variante "hero" do
/// design system): o valor grande e, embaixo, o preço por kg. Como a
/// etiqueta de gôndola (e o ícone do app), tem o furo à esquerda, os cantos
/// de 8 do lado do furo e de 14 do outro, e a sombra `shadow-raised`.
class PriceTagHero extends StatelessWidget {
  const PriceTagHero({required this.price, this.unitLine, this.unitLineSpoken, super.key});

  final Money price;

  /// "R$ 5,58/kg"; sem ele, a etiqueta só mostra o valor.
  final String? unitLine;

  /// A [unitLine] para o leitor de tela, quando ela tem sinais que ele lê
  /// ao pé da letra ("o quilo" no lugar de "/kg").
  final String? unitLineSpoken;

  /// O furo: 9 de diâmetro, a 12 da borda (`.bipa-tag::before`).
  static const holeSize = 9.0;
  static const _holeInset = 12.0;

  /// A forma da etiqueta: o lado do furo é mais fechado.
  static const borderRadius = BorderRadius.horizontal(
    left: Radius.circular(BipaRadius.sm),
    right: Radius.circular(BipaRadius.md),
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final unitLine = this.unitLine;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      label: [price.format(), ?(unitLineSpoken ?? unitLine)].join(', '),
      excludeSemantics: true,
      child: Container(
        // O furo fica nos 32 da esquerda, e o texto começa depois dele.
        padding: const EdgeInsets.fromLTRB(BipaSpacing.s8, BipaSpacing.s2, BipaSpacing.s4, BipaSpacing.s2),
        decoration: BoxDecoration(
          color: colors.price,
          borderRadius: borderRadius,
          // `shadow-raised`: 0 2px 6px, mais forte no tema escuro.
          boxShadow: [
            BoxShadow(
              color: colors.scrim.withValues(alpha: dark ? 0.5 : 0.16),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // O furo fica à esquerda nos dois sentidos de leitura, como na
            // etiqueta de verdade e no ícone do app.
            Positioned(
              left: _holeInset - BipaSpacing.s8,
              top: 0,
              bottom: 0,
              child: Center(
                child: Container(
                  key: const ValueKey('price-tag-hole'),
                  width: holeSize,
                  height: holeSize,
                  decoration: BoxDecoration(color: colors.ground, shape: BoxShape.circle),
                ),
              ),
            ),
            _content(colors, unitLine),
          ],
        ),
      ),
    );
  }

  Widget _content(BipaColors colors, String? unitLine) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: Money.symbol,
              style: BipaText.title.copyWith(color: colors.onPrice),
            ),
            TextSpan(
              text: price.formatDecimal(),
              style: BipaText.priceHero.copyWith(color: colors.onPrice),
            ),
          ],
        ),
      ),
      if (unitLine != null) Text(unitLine, style: BipaText.caption.copyWith(color: colors.onPrice)),
    ],
  );
}
