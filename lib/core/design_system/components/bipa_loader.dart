import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:flutter/material.dart';

/// O indicador de carregamento do design system (`.bipa-loader`, guia do
/// Button, "Carregando"): as quatro barras de código, o símbolo antigo, que
/// pulsam em sequência no lugar de um círculo girando. Serve para qualquer
/// espera curta: o ícone de "Fazer backup agora", o título de "Conferindo o
/// arquivo" e o rótulo do botão que restaura.
///
/// Com "Remover animações", as barras ficam paradas. O leitor de tela ouve
/// [semanticLabel]; sem ele, o indicador é só decoração do que está ao lado.
class BipaLoader extends StatefulWidget {
  const BipaLoader({this.color, this.height = 20, this.semanticLabel, super.key});

  /// A cor das barras; `ink` por padrão.
  final Color? color;

  /// A altura das barras; a largura acompanha.
  final double height;

  final String? semanticLabel;

  @override
  State<BipaLoader> createState() => _BipaLoaderState();
}

class _BipaLoaderState extends State<BipaLoader> with SingleTickerProviderStateMixin {
  /// Um ciclo: cada barra acende e apaga, uma depois da outra.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );

  /// As larguras das barras, em fração da altura, como no código de barras.
  static const _widths = [0.2, 0.12, 0.2, 0.2];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  /// A opacidade da barra [index] no instante [t] do ciclo: cada uma acende
  /// num quarto dele.
  static double _opacity(int index, double t) {
    final phase = (t - index / _widths.length) % 1;
    final glow = phase < 0.5 ? 1 - (phase * 2 - 0.5).abs() * 2 : 0.0;
    return 0.35 + 0.65 * glow.clamp(0, 1);
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? context.colors.ink;
    final height = widget.height;
    final gap = height * 0.12;
    final bars = AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < _widths.length; i++) ...[
            if (i > 0) SizedBox(width: gap),
            Opacity(
              opacity: _pulse.isAnimating ? _opacity(i, _pulse.value) : 1,
              child: Container(
                width: height * _widths[i],
                height: height,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(height * 0.06)),
              ),
            ),
          ],
        ],
      ),
    );
    final label = widget.semanticLabel;
    if (label == null) return ExcludeSemantics(child: bars);
    return Semantics(label: label, excludeSemantics: true, child: bars);
  }
}
