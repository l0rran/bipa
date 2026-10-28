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
/// Compacta ([compact]), a barra encolhe de 72 para 52 px, os rótulos somem e
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

  static const _barHeight = 72.0;
  static const _compactBarHeight = 52.0;
  static const _scanSize = 64.0;
  static const _compactScanSize = 56.0;
  // O quanto o botão de bipar passa da borda de cima da pílula. Compacto, ele
  // sobe um pouco menos, na proporção do `.is-compact .bipa-scan` do design
  // system (de 18 para 16 px lá; de 22 para 20 aqui).
  static const _scanLift = 22.0;
  static const _compactScanLift = 20.0;

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
      // O botão de bipar sobe 22 px acima da pílula. A caixa inclui essa parte,
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
                    filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: ColoredBox(
                      color: colors.surfaceGlass,
                      child: Row(
                        children: [
                          for (var i = 0; i < half; i++) destination(i),
                          const SizedBox(width: 76),
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
                    padding: const EdgeInsets.only(top: 4),
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

class _ScanButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final colors = context.colors;
    final onLongPress = this.onLongPress;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      onLongPress: onLongPress,
      onLongPressHint: longPressLabel,
      child: Material(
        color: colors.brand,
        shape: const CircleBorder(),
        elevation: 4,
        shadowColor: colors.ink.withValues(alpha: 0.4),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            HapticFeedback.lightImpact();
            onPressed();
          },
          onLongPress: onLongPress == null
              ? null
              : () {
                  HapticFeedback.mediumImpact();
                  onLongPress();
                },
          child: SizedBox.square(
            dimension: size,
            child: Icon(Icons.qr_code_scanner_rounded, size: 30, color: colors.onBrand),
          ),
        ),
      ),
    );
  }
}
