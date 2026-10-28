import 'package:bipa/core/design_system/bipa_metrics.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/design_system/bipa_typography.dart';
import 'package:flutter/material.dart';

/// A etiqueta amarela de preço em destaque (PriceTag, variante "hero" do
/// design system): o valor grande e, embaixo, o preço por kg.
class PriceTagHero extends StatelessWidget {
  const PriceTagHero({required this.value, this.unitLine, super.key});

  /// O valor sem o "R$": "27,90".
  final String value;

  /// "R$ 5,58/kg"; sem ele, a etiqueta só mostra o valor.
  final String? unitLine;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final unitLine = this.unitLine;
    return Semantics(
      label: [r'R$ ' + value, ?unitLine].join(', '),
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
                  TextSpan(text: r'R$', style: BipaText.title.copyWith(color: colors.onPrice)),
                  TextSpan(text: value, style: BipaText.priceHero.copyWith(color: colors.onPrice)),
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
