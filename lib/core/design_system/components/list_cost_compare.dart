import 'package:bipa/core/design_system/bipa_metrics.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/design_system/bipa_typography.dart';
import 'package:flutter/material.dart';

/// Uma linha da comparação: o mercado, o total e o tamanho da barra.
@immutable
class ListCostRow {
  const ListCostRow({required this.name, required this.value, this.fraction, this.note});

  final String name;

  /// O total já formatado: "R$ 84,30".
  final String value;

  /// O total em relação ao maior, de 0 a 1. `null` tira a barra: o total de
  /// um mercado sem preço de tudo não se compara com o dos outros.
  final double? fraction;

  /// Uma ressalva em cinza, como "preços de até 12 dias · sem preço de 2
  /// itens".
  final String? note;
}

/// "Sua lista em cada mercado" (Compare do design system): uma barra por
/// mercado. Com [bestLabel], a primeira linha é a mais barata, com a barra
/// em tinta e o selo; as outras ficam neutras. Sem ele (quando a comparação
/// não é justa), nenhuma linha se destaca.
class ListCostCompare extends StatelessWidget {
  const ListCostCompare({required this.rows, this.bestLabel, super.key});

  final List<ListCostRow> rows;

  /// "mais barato".
  final String? bestLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(BipaRadius.lg)),
      child: Padding(
        padding: const EdgeInsets.all(BipaSpacing.s4),
        child: Column(
          children: [
            for (final (index, row) in rows.indexed) ...[
              if (index > 0) const SizedBox(height: BipaSpacing.s3),
              _CompareRow(row: row, best: index == 0 && rows.length > 1 ? bestLabel : null),
            ],
          ],
        ),
      ),
    );
  }
}

class _CompareRow extends StatelessWidget {
  const _CompareRow({required this.row, this.best});

  final ListCostRow row;
  final String? best;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final best = this.best;
    final note = row.note;
    final fraction = row.fraction;
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: row.name),
                      if (best != null)
                        TextSpan(
                          text: ' · $best',
                          style: TextStyle(color: colors.positiveText, fontWeight: FontWeight.w700),
                        ),
                    ],
                  ),
                  style: BipaText.body.copyWith(fontSize: 15, fontWeight: FontWeight.w600, color: colors.ink),
                ),
              ),
              const SizedBox(width: BipaSpacing.s2),
              Text(row.value, style: BipaText.number.copyWith(color: colors.ink)),
            ],
          ),
          if (fraction != null) ...[
            const SizedBox(height: BipaSpacing.s2),
            // Desenhada à mão: o LinearProgressIndicator do Material 3 põe um
            // vão e um ponto no fim que o design system não tem.
            ClipRRect(
              borderRadius: BorderRadius.circular(BipaRadius.pill),
              child: ColoredBox(
                color: colors.surfaceSunken,
                child: SizedBox(
                  height: 10,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: fraction.clamp(0.0, 1.0)),
                    duration: BipaMotion.slow,
                    curve: BipaMotion.spring,
                    builder: (context, value, _) => FractionallySizedBox(
                      alignment: AlignmentDirectional.centerStart,
                      widthFactor: value.clamp(0.0, 1.0),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: best != null ? colors.ink : colors.line,
                          borderRadius: BorderRadius.circular(BipaRadius.pill),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
          if (note != null) ...[
            const SizedBox(height: BipaSpacing.s1),
            Text(note, style: BipaText.caption.copyWith(color: colors.inkMuted)),
          ],
        ],
      ),
    );
  }
}
