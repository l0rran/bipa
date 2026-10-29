import 'dart:math' as math;

import 'package:bipa/core/design_system/bipa_metrics.dart';
import 'package:bipa/core/design_system/bipa_palette.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/design_system/bipa_typography.dart';
import 'package:flutter/material.dart';

/// Estado do medidor. O design system não conhece o domínio: a tela converte
/// o nível do estoque para este estado.
enum GaugeState {
  /// No "ter sempre" ou acima: anel fechado e neutro.
  full,

  /// Abaixo do "ter sempre": arco coral com a fração.
  low,

  /// Zerado: anel tracejado.
  empty,
}

/// Medidor de nível: um anel que enche até o "ter sempre", com a quantidade
/// no centro. Em dia, o anel fica fechado e neutro; acabando, o arco coral
/// mostra a fração; acabou, o anel fica tracejado.
class StockGauge extends StatelessWidget {
  const StockGauge({
    required this.quantityLabel,
    required this.state,
    required this.fraction,
    required this.semanticsLabel,
    this.size = 40,
    super.key,
  });

  /// O número no centro, já formatado (ex.: `2`).
  final String quantityLabel;
  final GaugeState state;

  /// Quanto do "ter sempre" está em casa, de 0 a 1.
  final double fraction;

  /// O estado por extenso para o leitor de tela, ex.: "2 de 4 un".
  final String semanticsLabel;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final numberColor = state == GaugeState.full ? colors.ink : colors.alertText;
    // Com letra grande o anel cresce, para o número crescer junto (H9): metade
    // do aumento da letra, no máximo 1,5 vez. Em 100% fica do tamanho de sempre.
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final ring = size * (1 + (scale - 1) * 0.5).clamp(1.0, 1.5);

    return Semantics(
      label: semanticsLabel,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: ring,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: fraction),
          duration: BipaMotion.slow,
          curve: BipaMotion.spring,
          builder: (context, value, child) => CustomPaint(
            painter: _GaugePainter(fraction: value, state: state, colors: colors),
            child: child,
          ),
          // O número encolhe para caber dentro do anel em vez de passar do
          // traço (H3); como o anel cresce com a letra, o número também.
          child: Padding(
            padding: EdgeInsets.all(ring * 0.14),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  quantityLabel,
                  maxLines: 1,
                  style: BipaText.number.copyWith(fontSize: size * 0.42, color: numberColor),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  const _GaugePainter({required this.fraction, required this.state, required this.colors});

  final double fraction;
  final GaugeState state;
  final BipaColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.09;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    switch (state) {
      case GaugeState.full:
        canvas.drawArc(rect, 0, math.pi * 2, false, paint..color = colors.line);
      case GaugeState.low:
        canvas.drawArc(rect, 0, math.pi * 2, false, paint..color = colors.surfaceSunken);
        final sweep = math.pi * 2 * fraction.clamp(0.02, 1.0);
        canvas.drawArc(rect, -math.pi / 2, sweep, false, paint..color = colors.alert);
      case GaugeState.empty:
        // Anel tracejado: 12 traços curtos.
        const dashes = 12;
        const gap = math.pi * 2 / dashes;
        paint
          ..color = colors.alert.withValues(alpha: 0.7)
          ..strokeCap = StrokeCap.butt;
        for (var i = 0; i < dashes; i++) {
          canvas.drawArc(rect, -math.pi / 2 + i * gap, gap * 0.55, false, paint);
        }
    }
  }

  @override
  bool shouldRepaint(_GaugePainter old) => old.fraction != fraction || old.state != state || old.colors != colors;
}
