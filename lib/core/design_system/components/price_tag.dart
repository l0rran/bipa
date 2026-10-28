import 'package:bipa/core/design_system/bipa_metrics.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/design_system/bipa_typography.dart';
import 'package:bipa/core/money/money.dart';
import 'package:flutter/material.dart';

/// A etiqueta amarela de preço em destaque (PriceTag, variante "hero" do
/// design system): o valor grande e, embaixo, o preço por kg.
class PriceTagHero extends StatelessWidget {
  const PriceTagHero({required this.price, this.unitLine, super.key});

  final Money price;

  /// "R$ 5,58/kg"; sem ele, a etiqueta só mostra o valor.
  final String? unitLine;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final unitLine = this.unitLine;
    return Semantics(
      label: [price.format(), ?unitLine].join(', '),
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(BipaSpacing.s4, BipaSpacing.s3, BipaSpacing.s6, BipaSpacing.s3),
        decoration: BoxDecoration(color: colors.price, borderRadius: BorderRadius.circular(BipaRadius.lg)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: Money.symbol, style: BipaText.title.copyWith(color: colors.onPrice)),
                  TextSpan(text: price.formatDecimal(), style: BipaText.priceHero.copyWith(color: colors.onPrice)),
                ],
              ),
            ),
            if (unitLine != null) Text(unitLine, style: BipaText.caption.copyWith(color: colors.onPrice)),
          ],
        ),
      ),
    );
  }
}
