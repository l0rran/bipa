import 'dart:async';

import 'package:bipa/core/design_system/bipa_metrics.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/design_system/bipa_typography.dart';
import 'package:flutter/material.dart';

/// Controle −/+ de quantidade. Segurar − ou + repete o passo (a cada 110 ms,
/// depois do toque longo), e o número rola para cima ou para baixo.
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    required this.value,
    required this.unit,
    required this.decrementLabel,
    required this.incrementLabel,
    required this.onIncrement,
    this.onDecrement,
    this.highlighted = false,
    this.valueSpoken,
    super.key,
  });

  /// O número com a unidade, para o leitor de tela ("2 embalagens em
  /// casa"); sem ele, lê o número e a unidade soltos.

  /// O número já formatado.
  final String value;
  final String unit;
  final String decrementLabel;
  final String incrementLabel;
  final VoidCallback onIncrement;

  /// `null` desabilita o − (por exemplo, no zero).
  final VoidCallback? onDecrement;

  /// Destaca o fundo quando o item está abaixo do "ter sempre".
  final bool highlighted;

  final String? valueSpoken;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Com movimento reduzido no aparelho, o número troca sem deslizar.
    final duration = MediaQuery.disableAnimationsOf(context) ? Duration.zero : BipaMotion.base;
    return AnimatedContainer(
      duration: duration,
      // Mínima, não fixa: com fonte grande, o número cabe (H3).
      constraints: const BoxConstraints(minHeight: 52),
      // O círculo de 40 fica a 6 da borda; a área de toque, de 48, a 2.
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: ShapeDecoration(
        shape: const StadiumBorder(),
        color: highlighted ? colors.alertSoft : colors.surfaceSunken,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RepeatButton(icon: Icons.remove_rounded, label: decrementLabel, onStep: onDecrement),
          Flexible(
            child: Semantics(
              label: valueSpoken,
              excludeSemantics: valueSpoken != null,
              // Largura mínima, não fixa: com fonte grande, um número de dois ou
              // três dígitos cabe em vez de quebrar a linha (H3). Se nem assim
              // couber entre os botões, o número encolhe.
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 48),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedSwitcher(
                        duration: duration,
                        switchInCurve: BipaMotion.spring,
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(animation),
                            child: child,
                          ),
                        ),
                        child: Text(
                          value,
                          key: ValueKey(value),
                          style: BipaText.number.copyWith(
                            fontSize: 20,
                            color: highlighted ? colors.alertText : colors.ink,
                          ),
                        ),
                      ),
                      Text(unit.toUpperCase(), style: BipaText.caption.copyWith(fontSize: 10, color: colors.inkMuted)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          _RepeatButton(icon: Icons.add_rounded, label: incrementLabel, onStep: onIncrement),
        ],
      ),
    );
  }
}

class _RepeatButton extends StatefulWidget {
  const _RepeatButton({required this.icon, required this.label, required this.onStep});

  final IconData icon;
  final String label;
  final VoidCallback? onStep;

  @override
  State<_RepeatButton> createState() => _RepeatButtonState();
}

class _RepeatButtonState extends State<_RepeatButton> {
  Timer? _repeat;

  void _start() {
    final step = widget.onStep;
    if (step == null) return;
    _repeat = Timer.periodic(const Duration(milliseconds: 110), (_) => step());
  }

  void _stop() {
    _repeat?.cancel();
    _repeat = null;
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final enabled = widget.onStep != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      excludeSemantics: true,
      onTap: widget.onStep,
      child: GestureDetector(
        onTap: widget.onStep,
        onLongPressStart: (_) => _start(),
        onLongPressEnd: (_) => _stop(),
        onLongPressCancel: _stop,
        // O toque vale nos 48 dp em volta do círculo, não só nele.
        behavior: HitTestBehavior.opaque,
        child: SizedBox.square(
          dimension: 48,
          child: Center(
            child: AnimatedOpacity(
              duration: BipaMotion.base,
              opacity: enabled ? 1 : 0.45,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: enabled ? colors.surface : Colors.transparent, shape: BoxShape.circle),
                child: Icon(widget.icon, size: 20, color: colors.ink),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
