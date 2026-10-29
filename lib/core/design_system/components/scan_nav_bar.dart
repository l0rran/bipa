import 'dart:ui' show ImageFilter, clampDouble, lerpDouble;

import 'package:bipa/core/design_system/bipa_metrics.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/design_system/bipa_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Um destino da barra de navegação.
class ScanNavDestination {
  const ScanNavDestination({required this.icon, required this.selectedIcon, required this.label});

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// Barra de navegação de vidro, flutuante, com o botão de bipar no centro em
/// amarelo. Os destinos se dividem metade de cada lado do botão.
///
/// Compacta ([compact]), a barra encolhe de 68 para 52 px, os rótulos somem e
/// o botão de bipar diminui de 64 para 56 px, como no iOS 26: o conteúdo
/// ganha espaço enquanto se rola para baixo. O espaço que a barra ocupa no
/// layout não muda, para as telas não se reorganizarem a cada rolagem; só o
/// desenho encolhe para baixo. Quem decide quando encolher é o
/// [ScanNavBarCompactController].
///
/// Use com `Scaffold(extendBody: true)` para o conteúdo passar por trás.
class ScanNavBar extends StatelessWidget {
  const ScanNavBar({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    required this.onScan,
    required this.scanLabel,
    this.onScanLongPress,
    this.scanLongPressLabel,
    this.compact = false,
    this.above,
    super.key,
  });

  final List<ScanNavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onScan;
  final String scanLabel;

  /// Segurar o botão abre mais opções (protótipo "Menu do bipar").
  final VoidCallback? onScanLongPress;

  /// O que o leitor de tela diz do toque longo: "Mais opções".
  final String? scanLongPressLabel;

  /// Barra encolhida, sem os rótulos (eles continuam no leitor de tela).
  final bool compact;

  /// O que fica logo acima da barra (a barra da compra). Desce junto quando
  /// a barra encolhe, para não sobrar um vão entre os dois.
  final Widget? above;

  /// O anel que respira no botão de bipar, para os testes acharem.
  @visibleForTesting
  static const ringKey = ValueKey('scan-ring');

  // As medidas vêm do `.bipa-nav` e do `.bipa-scan` do design system.
  static const _barHeight = 68.0;
  static const _compactBarHeight = 52.0;
  static const _scanSize = 64.0;
  static const _compactScanSize = 56.0;

  // O quanto o botão de bipar passa da borda de cima da pílula. No CSS ele tem
  // `margin-top: -40px` numa caixa de 64 px centrada na pílula de 68, o que
  // deixa 18 px para fora; compacto, são 56 px com `margin-top: -28px` numa
  // pílula de 52, ou seja, 16 px.
  static const _scanLift = 18.0;
  static const _compactScanLift = 16.0;

  // O desfoque do vidro (`backdrop-filter: blur(18px)`).
  static const _blur = 18.0;

  // A coluna do meio, onde o botão de bipar fica. O design system reserva 84 px
  // e 8 de folga nas bordas; aqui são 76 e nenhuma folga, para cada rótulo
  // ganhar 6 dp a mais de largura (a letra grande já aperta os rótulos, H8).
  static const _scanGap = 76.0;

  @override
  Widget build(BuildContext context) {
    // Com movimento reduzido, a troca é imediata.
    final still = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: compact ? 1 : 0),
      duration: still ? Duration.zero : BipaMotion.slow,
      curve: BipaMotion.spring,
      builder: (context, t, _) => _build(context, t),
    );
  }

  /// A barra em [t]: 0 é a normal e 1 a compacta. A mola passa um pouco de
  /// 0 e de 1 antes de assentar.
  Widget _build(BuildContext context, double t) {
    final colors = context.colors;
    final half = (destinations.length / 2).ceil();
    final barHeight = lerpDouble(_barHeight, _compactBarHeight, t)!;
    final scanSize = lerpDouble(_scanSize, _compactScanSize, t)!;
    final scanLift = lerpDouble(_scanLift, _compactScanLift, t)!;
    final labelFactor = clampDouble(1 - t, 0, 1);

    Widget destination(int index) => Expanded(
      child: _Destination(
        destination: destinations[index],
        selected: index == selectedIndex,
        labelFactor: labelFactor,
        onTap: () => onSelected(index),
      ),
    );

    final bar = SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      // O botão de bipar sobe 18 px acima da pílula. A caixa inclui essa parte,
      // porque o toque não passa dos limites do pai. A altura é sempre a da
      // barra normal: compacta, a pílula encolhe para baixo e o toque acima
      // dela vai para o conteúdo.
      child: SizedBox(
        height: _barHeight + _scanLift,
        child: Stack(
          alignment: Alignment.topCenter,
          // A mola passa um pouco do tamanho normal antes de assentar.
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: barHeight,
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  shape: const StadiumBorder(),
                  shadows: [
                    BoxShadow(color: colors.ink.withValues(alpha: 0.12), blurRadius: 24, offset: const Offset(0, 8)),
                  ],
                ),
                child: ClipPath(
                  clipper: const ShapeBorderClipper(shape: StadiumBorder()),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: _blur, sigmaY: _blur),
                    child: ColoredBox(
                      color: colors.surfaceGlass,
                      child: Row(
                        children: [
                          for (var i = 0; i < half; i++) destination(i),
                          const SizedBox(width: _scanGap),
                          for (var i = half; i < destinations.length; i++) destination(i),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: _barHeight + _scanLift - barHeight - scanLift,
              child: _ScanButton(
                label: scanLabel,
                size: scanSize,
                onPressed: onScan,
                onLongPress: onScanLongPress,
                longPressLabel: scanLongPressLabel,
              ),
            ),
          ],
        ),
      ),
    );

    final above = this.above;
    if (above == null) return bar;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Só no desenho (e no toque), sem mudar o layout.
        Transform.translate(offset: Offset(0, _barHeight - barHeight), child: above),
        bar,
      ],
    );
  }
}

/// Decide, pela rolagem do conteúdo, quando a [ScanNavBar] fica compacta.
///
/// Rolando para baixo, longe do topo, a barra encolhe; rolando para cima, ela
/// volta. No topo, ou quando o conteúdo nem rola, ela fica inteira. Só conta a
/// rolagem vertical do conteúdo à vista: listas de abas escondidas, telas
/// cobertas por outra e listas aninhadas ou horizontais não mexem na barra.
///
/// Ligue [onScrollNotification] e [onScrollMetricsNotification] a
/// `NotificationListener`s em volta do conteúdo, e chame [expand] ao trocar de
/// aba.
class ScanNavBarCompactController extends ValueNotifier<bool> {
  ScanNavBarCompactController() : super(false);

  /// Quanto é preciso rolar numa mesma direção para a barra mudar. Menos que
  /// isso é o tremor do dedo e não faz a barra piscar.
  ///
  /// O design system (`bundle.js`) compara 4 px com a posição do evento
  /// anterior; aqui são 8 px acumulados desde que a direção mudou. Chega um
  /// evento de rolagem por quadro, então 4 px por evento são uns 240 px/s: o
  /// design system só reage a um gesto rápido, e uma rolagem lenta e
  /// deliberada nunca encolheria a barra. Somar a distância resolve isso, e os
  /// 8 px mantêm a imunidade ao tremor do dedo. Por isso a diferença fica.
  static const hysteresis = 8.0;

  /// Até aqui a barra não encolhe (os 24 px do design system).
  static const topZone = 24.0;

  /// Onde a rolagem mudou de direção pela última vez.
  double? _anchor;
  bool? _scrollingDown;

  /// A barra volta ao tamanho normal (ao trocar de aba, por exemplo).
  void expand() {
    _anchor = null;
    _scrollingDown = null;
    value = false;
  }

  /// Para `NotificationListener<ScrollNotification>`. Nunca consome a
  /// notificação.
  bool onScrollNotification(ScrollNotification notification) {
    final metrics = notification.metrics;
    if (!_counts(metrics, notification.depth, notification.context)) return false;
    if (_atRest(metrics)) {
      expand();
      return false;
    }
    if (notification is! ScrollUpdateNotification || metrics.outOfRange) return false;
    final delta = notification.scrollDelta ?? 0;
    if (delta == 0) return false;

    final down = delta > 0;
    final anchor = down == _scrollingDown ? _anchor : null;
    if (anchor == null) {
      // Mudou de direção: a distância conta a partir daqui.
      _scrollingDown = down;
      _anchor = metrics.pixels - delta;
    }
    if ((metrics.pixels - _anchor!).abs() < hysteresis) return false;
    if (!down) {
      value = false;
    } else if (metrics.pixels > metrics.minScrollExtent + topZone) {
      value = true;
    }
    return false;
  }

  /// Para `NotificationListener<ScrollMetricsNotification>`: quando o
  /// conteúdo diminui e deixa de rolar, a barra volta. Nunca consome a
  /// notificação.
  bool onScrollMetricsNotification(ScrollMetricsNotification notification) {
    if (_counts(notification.metrics, notification.depth, notification.context) && _atRest(notification.metrics)) {
      expand();
    }
    return false;
  }

  /// Só a lista vertical de fora, e à vista: uma aba escondida ou uma tela
  /// coberta por outra têm os tickers desligados.
  static bool _counts(ScrollMetrics metrics, int depth, BuildContext? context) =>
      metrics.axis == Axis.vertical &&
      depth == 0 &&
      (context == null || TickerMode.getValuesNotifier(context).value.enabled);

  /// No topo ou num conteúdo que não rola.
  static bool _atRest(ScrollMetrics metrics) =>
      metrics.maxScrollExtent <= metrics.minScrollExtent || metrics.pixels <= metrics.minScrollExtent;
}

class _Destination extends StatelessWidget {
  const _Destination({
    required this.destination,
    required this.selected,
    required this.labelFactor,
    required this.onTap,
  });

  final ScanNavDestination destination;
  final bool selected;

  /// Quanto do rótulo aparece: 1 na barra normal, 0 na compacta. Sumido, ele
  /// continua no rótulo acessível.
  final double labelFactor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      excludeSemantics: true,
      // excludeSemantics descarta a ação do InkResponse: ela vai aqui.
      onTap: onTap,
      child: InkResponse(
        onTap: onTap,
        radius: 36,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: BipaMotion.slow,
              curve: BipaMotion.spring,
              width: selected ? 52 : 32,
              height: 30,
              decoration: ShapeDecoration(
                shape: const StadiumBorder(),
                color: selected ? colors.brandSoft : Colors.transparent,
              ),
              child: Icon(
                selected ? destination.selectedIcon : destination.icon,
                size: 22,
                color: selected ? colors.ink : colors.inkMuted,
              ),
            ),
            // O rótulo recolhe de baixo para cima e some junto.
            ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: labelFactor,
                child: Opacity(
                  opacity: labelFactor,
                  child: Padding(
                    // 30 do ícone, 2 de vão e 16 do rótulo: 48 px no meio dos
                    // 68 da barra, o indicador a 10 px do topo (como no CSS).
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      destination.label,
                      maxLines: 1,
                      style: BipaText.caption.copyWith(
                        fontSize: 12,
                        color: selected ? colors.ink : colors.inkMuted,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanButton extends StatefulWidget {
  const _ScanButton({
    required this.label,
    required this.size,
    required this.onPressed,
    this.onLongPress,
    this.longPressLabel,
  });

  final String label;

  /// 64 px, ou 56 na barra compacta.
  final double size;
  final VoidCallback onPressed;
  final VoidCallback? onLongPress;
  final String? longPressLabel;

  @override
  State<_ScanButton> createState() => _ScanButtonState();
}

class _ScanButtonState extends State<_ScanButton> with SingleTickerProviderStateMixin {
  /// Um ciclo do anel que respira (`bipa-breathe`: 2,4 s, sem fim).
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  /// O anel cresce até 1,22 vez o botão enquanto some de 35% a 0 de opacidade.
  static const _ringScale = 1.22;
  static const _ringOpacity = 0.35;

  bool _still = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Movimento reduzido: o anel para e nem chega a ser desenhado. Fora da
    // tela (uma câmera aberta por cima, por exemplo) o ticker se cala sozinho,
    // então a barra escondida não gasta quadros.
    _still = MediaQuery.disableAnimationsOf(context);
    if (_still) {
      _breath.stop();
    } else if (!_breath.isAnimating) {
      _breath.repeat();
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  /// O anel em [t], de 0 a 1 no ciclo. Como no CSS, a curva vale para cada
  /// metade: de 0 a 50% o anel cresce e some, de 50 a 100% encolhe e volta.
  static ({double scale, double opacity}) _ringAt(double t) {
    final growing = t < 0.5;
    final p = BipaMotion.standard.transform(growing ? t * 2 : (t - 0.5) * 2);
    final k = growing ? p : 1 - p;
    return (scale: lerpDouble(1, _ringScale, k)!, opacity: lerpDouble(_ringOpacity, 0, k)!);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final onLongPress = widget.onLongPress;
    return Stack(
      alignment: Alignment.center,
      // O anel passa dos limites do botão.
      clipBehavior: Clip.none,
      children: [
        if (!_still)
          Positioned.fill(
            child: IgnorePointer(
              child: ExcludeSemantics(
                // Só o anel repinta a cada quadro.
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _breath,
                    builder: (context, _) {
                      final ring = _ringAt(_breath.value);
                      return Transform.scale(
                        scale: ring.scale,
                        child: DecoratedBox(
                          key: ScanNavBar.ringKey,
                          decoration: ShapeDecoration(
                            shape: const CircleBorder(),
                            color: colors.brand.withValues(alpha: ring.opacity),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        Semantics(
          button: true,
          label: widget.label,
          excludeSemantics: true,
          onTap: widget.onPressed,
          onLongPress: onLongPress,
          onLongPressHint: widget.longPressLabel,
          child: Material(
            color: colors.brand,
            shape: const CircleBorder(),
            elevation: 4,
            shadowColor: colors.ink.withValues(alpha: 0.4),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () {
                HapticFeedback.lightImpact();
                widget.onPressed();
              },
              onLongPress: onLongPress == null
                  ? null
                  : () {
                      HapticFeedback.mediumImpact();
                      onLongPress();
                    },
              child: SizedBox.square(
                dimension: widget.size,
                child: Icon(Icons.qr_code_scanner_rounded, size: 30, color: colors.onBrand),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
