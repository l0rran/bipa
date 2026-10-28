import 'dart:math' as math;

import 'package:bipa/core/design_system/bipa_metrics.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:flutter/material.dart';

/// Um mercado no mapa: onde ele fica em relação a quem olha, em metros.
@immutable
class MarketMapPin {
  const MarketMapPin({required this.east, required this.north, this.here = false, this.best = false});

  final double east;
  final double north;

  /// A pessoa está nele: o alfinete fica cheio.
  final bool here;

  /// O mais barato para a lista: ganha o anel verde.
  final bool best;
}

/// O mapa esquemático da tela de Mercados (protótipo "Mercados"): quem olha
/// no meio e os mercados em volta, na escala certa entre eles. Não é um mapa
/// de ruas: o app é offline e não depende de serviço de mapas.
class MarketMap extends StatelessWidget {
  const MarketMap({required this.pins, required this.semanticsLabel, super.key});

  final List<MarketMapPin> pins;

  /// "Mapa com 3 mercados perto de você".
  final String semanticsLabel;

  static const _height = 200.0;
  static const _pinSize = 36.0;

  /// Folga nas bordas para o alfinete não ser cortado.
  static const _margin = 28.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      label: semanticsLabel,
      image: true,
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(BipaRadius.lg),
        child: ColoredBox(
          color: colors.placeSoft,
          child: SizedBox(
            height: _height,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final center = Offset(constraints.maxWidth / 2, _height / 2 + _pinSize / 4);
                // A mesma escala nos dois eixos, para as distâncias ficarem certas.
                final reach = pins.fold<double>(1, (max, pin) => math.max(max, _reach(pin, center)));
                final scale = 1 / reach;
                Offset place(MarketMapPin pin) => center + Offset(pin.east * scale, -pin.north * scale);
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(left: center.dx - 8, top: center.dy - 8, child: const _Me()),
                    for (final pin in pins.where((p) => !p.here)) _positioned(place(pin), _Pin(pin: pin)),
                    // O mercado em que a pessoa está fica por cima.
                    for (final pin in pins.where((p) => p.here)) _positioned(place(pin), _Pin(pin: pin)),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Quantos metros cada pixel precisa valer para este alfinete caber no
  /// mapa. Para cima, a gota inteira precisa caber; para baixo, só a ponta.
  static double _reach(MarketMapPin pin, Offset center) {
    final sideways = center.dx - _margin;
    final up = center.dy - _pinTotalHeight - BipaSpacing.s2;
    final down = _height - center.dy - _margin;
    return math.max(pin.east.abs() / sideways, pin.north / (pin.north > 0 ? up : -down));
  }

  /// Da ponta ao topo da gota girada: a diagonal do quadrado.
  static const _pinTotalHeight = _pinSize * math.sqrt2;

  /// A ponta do alfinete (o canto girado 45°, a meia diagonal do centro)
  /// fica no lugar do mercado.
  static Widget _positioned(Offset at, Widget pin) => Positioned(
    left: at.dx - _pinSize / 2,
    top: at.dy - _pinSize / 2 - _pinSize * math.sqrt1_2,
    child: pin,
  );
}

class _Me extends StatelessWidget {
  const _Me();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.place,
        border: Border.all(color: colors.surface, width: 2),
        boxShadow: [BoxShadow(color: colors.place.withValues(alpha: 0.25), spreadRadius: 5)],
      ),
    );
  }
}

class _Pin extends StatelessWidget {
  const _Pin({required this.pin});

  final MarketMapPin pin;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    const size = MarketMap._pinSize;
    // Uma gota: três cantos redondos e a ponta para baixo.
    const shape = BorderRadius.only(
      topLeft: Radius.circular(size / 2),
      topRight: Radius.circular(size / 2),
      bottomRight: Radius.circular(size / 2),
      bottomLeft: Radius.circular(4),
    );
    return Transform.rotate(
      angle: -math.pi / 4,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: pin.here ? colors.place : colors.surface,
          borderRadius: shape,
          border: pin.best ? Border.all(color: colors.positiveText, width: 3) : null,
          boxShadow: [BoxShadow(color: colors.scrim.withValues(alpha: 0.18), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Transform.rotate(
          angle: math.pi / 4,
          child: Icon(Icons.storefront_rounded, size: 18, color: pin.here ? colors.onPlace : colors.place),
        ),
      ),
    );
  }
}
