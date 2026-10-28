import 'package:bipa/core/design_system/bipa_metrics.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/design_system/bipa_typography.dart';
import 'package:flutter/material.dart';

/// Um preço numa lista de preços (MarketPrice do design system): o ícone, o
/// nome com uma linha de apoio e o valor à direita, com o selo opcional
/// embaixo ("menor preço", "menor por kg").
@immutable
class PriceRowData {
  const PriceRowData({
    required this.icon,
    required this.title,
    required this.value,
    this.meta,
    this.metaIcon,
    this.metaAlert = false,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String value;

  /// "R$ 5,58/kg", "há 5 dias".
  final String? meta;
  final IconData? metaIcon;

  /// A linha de apoio em coral, para um preço antigo.
  final bool metaAlert;

  /// Selo em verde sob o valor; só o melhor da lista tem.
  final String? badge;
}

/// O cartão com as linhas de preço, separadas por um fio.
class PriceRowList extends StatelessWidget {
  const PriceRowList({required this.rows, super.key});

  final List<PriceRowData> rows;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(BipaRadius.lg)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: BipaSpacing.s4, vertical: BipaSpacing.s2),
        child: Column(
          children: [
            for (final (index, row) in rows.indexed) ...[
              if (index > 0) Divider(height: 1, thickness: 1, indent: 56, color: colors.line),
              _PriceRow(row: row),
            ],
          ],
        ),
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.row});

  final PriceRowData row;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final meta = row.meta;
    final badge = row.badge;
    final metaColor = row.metaAlert ? colors.alertText : colors.inkMuted;
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: BipaSpacing.s3),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colors.surfaceSunken,
                borderRadius: BorderRadius.circular(BipaRadius.md),
              ),
              child: Icon(row.icon, size: 22, color: colors.ink),
            ),
            const SizedBox(width: BipaSpacing.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(row.title, style: BipaText.bodyLarge.copyWith(color: colors.ink)),
                  if (meta != null)
                    Row(
                      children: [
                        if (row.metaIcon case final icon?) ...[
                          Icon(icon, size: 14, color: metaColor),
                          const SizedBox(width: BipaSpacing.s1),
                        ],
                        Flexible(child: Text(meta, style: BipaText.body.copyWith(fontSize: 13, color: metaColor))),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(width: BipaSpacing.s3),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(row.value, style: BipaText.number.copyWith(color: colors.ink)),
                if (badge != null) Text(badge, style: BipaText.caption.copyWith(color: colors.positiveText)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
