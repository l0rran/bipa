import 'package:bipa/core/design_system/bipa_metrics.dart';
import 'package:bipa/core/design_system/bipa_palette.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/design_system/bipa_typography.dart';
import 'package:flutter/material.dart';

/// O gráfico do preço no tempo (PriceHistory do design system): a linha em
/// tinta sobre a área sombreada, o ponto amarelo no preço mais recente e os
/// meses embaixo.
///
/// O design system não conhece preços: a tela entrega os pontos já
/// normalizados, com x e y de 0 a 1 (y = 1 é o preço mais alto).
class PriceHistoryChart extends StatelessWidget {
  const PriceHistoryChart({
    required this.points,
    required this.axisLabels,
    required this.semanticsLabel,
    super.key,
  });

  /// Do mais antigo para o mais recente; o último ganha o ponto.
  final List<Offset> points;

  /// Os rótulos do eixo e onde ficam, de 0 a 1 (a mesma escala de x dos
  /// [points]): "mai" no começo de maio, "hoje" na ponta.
  final List<({String label, double at})> axisLabels;

  /// O gráfico por extenso, ex.: "Preço do kg nos últimos 6 meses, de R$ 5,90
  /// a R$ 4,99".
  final String semanticsLabel;

  static const _height = 96.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      label: semanticsLabel,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(BipaRadius.lg)),
        child: Padding(
          padding: const EdgeInsets.all(BipaSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: _height,
                child: CustomPaint(painter: _HistoryPainter(points: points, colors: colors)),
              ),
              const SizedBox(height: BipaSpacing.s2),
              // Cada rótulo no seu lugar; nas pontas, encostado na borda.
              SizedBox(
                height: 16,
                child: Stack(
                  children: [
                    for (final (:label, :at) in axisLabels)
                      Align(
                        alignment: Alignment(at.clamp(0.0, 1.0) * 2 - 1, 0),
                        child: Text(label, style: BipaText.caption.copyWith(color: colors.inkMuted)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryPainter extends CustomPainter {
  const _HistoryPainter({required this.points, required this.colors});

  final List<Offset> points;
  final BipaColors colors;

  /// Folga em cima e embaixo para o ponto não ser cortado.
  static const _dotRadius = 6.0;
  static const _stroke = 2.5;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    const inset = _dotRadius + _stroke;
    final height = size.height - inset * 2;
    Offset toCanvas(Offset p) => Offset(p.dx * size.width, inset + (1 - p.dy) * height);
    final canvasPoints = [for (final p in points) toCanvas(p)];

    final line = Path()..moveTo(canvasPoints.first.dx, canvasPoints.first.dy);
    for (final p in canvasPoints.skip(1)) {
      line.lineTo(p.dx, p.dy);
    }
    final area = Path.from(line)
      ..lineTo(canvasPoints.last.dx, size.height)
      ..lineTo(canvasPoints.first.dx, size.height)
      ..close();

    canvas
      ..drawPath(area, Paint()..color = colors.surfaceSunken)
      ..drawPath(
        line,
        Paint()
          ..color = colors.ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = _stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );

    final last = canvasPoints.last;
    canvas
      ..drawCircle(last, _dotRadius, Paint()..color = colors.price)
      ..drawCircle(
        last,
        _dotRadius,
        Paint()
          ..color = colors.ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = _stroke,
      );
  }

  @override
  bool shouldRepaint(_HistoryPainter oldDelegate) => oldDelegate.points != points || oldDelegate.colors != colors;
}
