import 'dart:math' as math;
import 'dart:ui' show ImageFilter, clampDouble, lerpDouble;

import 'package:bipa/core/design_system/bipa_metrics.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/design_system/bipa_typography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Um destino da barra de navegação.
class ScanNavDestination {
  const ScanNavDestination({required this.icon, required this.selectedIcon, required this.label});

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// Quanto o anel do botão de bipar respira (H16, guia `ScanNavBar.md`).
enum ScanRingBreath {
  /// Duas respirações (4,8 s) quando a barra aparece: o app abre ou volta, ou
  /// a pessoa volta da câmera ou de outra tela cheia. Trocar de aba não
  /// recomeça. Ficam abaixo dos 5 s do WCAG 2.2.2, sem controle para parar.
  twice,

  /// Sem fim: o convite ao primeiro bipe, enquanto a casa e a lista estão
  /// vazias e não há nada para ler ao lado.
  endless,

  /// Parado: durante a compra, a barra da compra é o destaque da tela.
  still,
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
/// Com letra grande (H8, quadro "NavLetraGrande", decidido em 28/10/2026: "A
/// até 160%, B acima"):
///
/// - Até [floatingScanScale] (160%), a barra de sempre: os rótulos crescem
///   até [largeTextScale] (130%) e, se não couberem, encolhem até caber, todos
///   no mesmo tamanho, em vez de serem cortados.
/// - Acima disso, o bipar sai do meio e flutua acima da barra, à direita, e
///   os quatro destinos dividem a largura. Os rótulos crescem com a letra até
///   caber e só então encolhem; a pílula cresce junto. O espaço reservado no
///   layout inclui o botão flutuante, para o fim das telas não ficar atrás
///   dele.
/// - A partir de [largeTextScale], ou com o TalkBack, a barra não encolhe ao
///   rolar ([canCompact]): ali o rótulo é a informação.
/// - Com [aboveReplacesScan] e o bipar flutuante, [above] (a barra da compra)
///   assume o papel do bipar, e o botão flutuante sai (H12, quadro
///   "NavLetraGrandeCompra", decisão A): um amarelo só no canto da tela.
///
/// Segurar um destino mostra o rótulo grande num balão, como o Large Content
/// Viewer do iOS. O balão é só dos destinos: segurar o bipar abre o menu.
///
/// O anel em volta do bipar respira como [ringBreath] pede, e nunca com
/// movimento reduzido.
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
    this.aboveReplacesScan = false,
    this.ringBreath = ScanRingBreath.twice,
    super.key,
  });

  final List<ScanNavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onScan;
  final String scanLabel;

  /// Segurar o botão abre mais opções (protótipo "Menu do bipar"). Recebe
  /// onde o botão fica na tela, em coordenadas globais e com a barra inteira
  /// (não a compacta), para o menu pôr o "×" no lugar dele.
  final ValueChanged<Rect>? onScanLongPress;

  /// O que o leitor de tela diz do toque longo: "Mais opções".
  final String? scanLongPressLabel;

  /// Barra encolhida, sem os rótulos (eles continuam no leitor de tela). Com
  /// letra grande ou com o TalkBack, a barra ignora o pedido ([canCompact]).
  final bool compact;

  /// O que fica logo acima da barra (a barra da compra). Desce junto quando
  /// a barra encolhe, para não sobrar um vão entre os dois.
  final Widget? above;

  /// Com o bipar flutuante (letra acima de 160%), [above] fica no lugar dele:
  /// o botão sai, e quem monta [above] liga nele o toque longo do menu do
  /// bipar ([floatsScan] diz quando). Sem [above], o bipar flutua como
  /// sempre; até 160%, nada muda.
  final bool aboveReplacesScan;

  /// Quanto o anel do bipar respira. Quem monta a barra decide pelo estado
  /// do app (compra em andamento, casa e lista vazias); a barra não o conhece.
  final ScanRingBreath ringBreath;

  /// O anel que respira no botão de bipar, para os testes acharem.
  @visibleForTesting
  static const ringKey = ValueKey('scan-ring');

  /// O balão com o rótulo grande, para os testes acharem.
  @visibleForTesting
  static const balloonKey = ValueKey('nav-balloon');

  /// A partir desta escala de letra, a barra não encolhe ao rolar, e os
  /// rótulos da barra com o bipar no meio param de crescer (como no
  /// `NavigationBar` do Flutter).
  static const largeTextScale = 1.3;

  /// Acima desta escala de letra, o bipar flutua acima da barra.
  static const floatingScanScale = 1.6;

  // A escala vem de uma conta com ponto flutuante: 12 × 1,6 ÷ 12 dá um pouco
  // mais que 1,6. A folga mantém os 160% do Android do lado da barra normal.
  static const _scaleTolerance = 0.005;

  // O rótulo: `BipaText.caption`, 12 px em linhas de 16.
  static const _labelSize = 12.0;
  static const _labelLineHeight = 16.0;

  // Folga de cada lado do rótulo, para dois rótulos vizinhos não se tocarem.
  static const _labelPadding = 2.0;

  // As medidas vêm do `.bipa-nav` e do `.bipa-scan` do design system.
  static const _barHeight = 68.0;
  static const _compactBarHeight = 52.0;
  static const _scanSize = 64.0;
  static const _compactScanSize = 56.0;

  // A margem da barra nas laterais e embaixo.
  static const _margin = 12.0;

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

  // O bipar flutuante (quadro "NavLetraGrande", B): 12 px acima da pílula e
  // 4 para dentro da margem; a pílula tem 8 px de folga nas laterais e 6 em
  // cima e embaixo, e o destino, 30 do indicador e 2 de vão até o rótulo.
  static const _floatingGap = 12.0;
  static const _floatingInset = 4.0;
  static const _floatingPadding = 8.0;
  static const _pillPadding = 6.0;
  static const _indicatorHeight = 30.0;
  static const _labelGap = 2.0;

  // O balão do rótulo grande fica 8 px acima do bipar da barra normal, e 12
  // acima da pílula quando o bipar flutua.
  static const _balloonGap = 8.0;

  /// A escala da letra no rótulo da barra. O Android 14 escala a letra de
  /// forma não linear, então a conta usa o tamanho do rótulo.
  static double textScaleOf(BuildContext context) => MediaQuery.textScalerOf(context).scale(_labelSize) / _labelSize;

  /// Se o bipar sai do meio e flutua acima da barra (acima de 160%).
  static bool floatsScan(BuildContext context) => textScaleOf(context) > floatingScanScale + _scaleTolerance;

  /// Se a barra pode encolher ao rolar: só com a letra abaixo de 130% e sem
  /// o TalkBack.
  static bool canCompact(BuildContext context) =>
      textScaleOf(context) < largeTextScale - _scaleTolerance && !MediaQuery.accessibleNavigationOf(context);

  @override
  Widget build(BuildContext context) {
    final scale = textScaleOf(context);
    final floating = floatsScan(context);
    final shrinkable = canCompact(context);
    // Com movimento reduzido, a troca é imediata.
    final still = MediaQuery.disableAnimationsOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = MediaQuery.paddingOf(context);
        final width = constraints.hasBoundedWidth ? constraints.maxWidth : MediaQuery.sizeOf(context).width;
        final barWidth = width - math.max(_margin, padding.left) - math.max(_margin, padding.right);
        if (floating) {
          final column = (barWidth - 2 * _floatingPadding) / destinations.length;
          return _buildFloating(context, _fitLabels(context, column, scale));
        }
        final column = (barWidth - _scanGap) / destinations.length;
        final labelScale = _fitLabels(context, column, math.min(scale, largeTextScale));
        return TweenAnimationBuilder<double>(
          tween: Tween(end: compact && shrinkable ? 1 : 0),
          duration: still ? Duration.zero : BipaMotion.slow,
          curve: BipaMotion.spring,
          builder: (context, t, _) => _build(context, t, labelScale),
        );
      },
    );
  }

  /// A escala em que todos os rótulos cabem numa coluna de [columnWidth]:
  /// [desired], se couber, ou a maior menor que ela que caiba. Os quatro
  /// usam a mesma, e a conta usa o peso do destino escolhido, o mais largo,
  /// para nada mudar de tamanho ao trocar de aba.
  double _fitLabels(BuildContext context, double columnWidth, double desired) {
    final available = columnWidth - 2 * _labelPadding;
    if (available <= 0) return desired;
    final style = DefaultTextStyle.of(context).style.merge(_labelStyle(context, selected: true));
    final direction = Directionality.of(context);
    double widestAt(double scale) {
      var widest = 0.0;
      for (final destination in destinations) {
        final painter = TextPainter(
          text: TextSpan(text: destination.label, style: style),
          textDirection: direction,
          textScaler: TextScaler.linear(scale),
          maxLines: 1,
        )..layout();
        widest = math.max(widest, painter.width);
        painter.dispose();
      }
      return widest;
    }

    // A conta parte do tamanho normal, para o resultado não depender da letra
    // pedida quando ela não cabe. A largura não cresce em proporção exata com
    // a letra (o arredondamento dos glifos), então confere de novo.
    var scale = math.min(desired, available / widestAt(1));
    for (var i = 0; i < 4; i++) {
      final widest = widestAt(scale);
      if (widest <= available) break;
      scale *= available / (widest + 0.5);
    }
    return scale;
  }

  static TextStyle _labelStyle(BuildContext context, {required bool selected}) {
    final colors = context.colors;
    return BipaText.caption.copyWith(
      fontSize: _labelSize,
      color: selected ? colors.ink : colors.inkMuted,
      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
    );
  }

  /// A pílula de vidro em volta de [child].
  static Widget _glass(BuildContext context, Widget child) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: const StadiumBorder(),
        shadows: [BoxShadow(color: colors.ink.withValues(alpha: 0.12), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: ClipPath(
        clipper: const ShapeBorderClipper(shape: StadiumBorder()),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: _blur, sigmaY: _blur),
          child: ColoredBox(color: colors.surfaceGlass, child: child),
        ),
      ),
    );
  }

  Widget _destination(
    int index, {
    required double labelFactor,
    required double labelScale,
    required double balloonGap,
  }) => Expanded(
    child: _Destination(
      destination: destinations[index],
      selected: index == selectedIndex,
      labelFactor: labelFactor,
      labelScale: labelScale,
      balloonGap: balloonGap,
      onTap: () => onSelected(index),
    ),
  );

  /// A barra com o bipar no meio, em [t]: 0 é a normal e 1 a compacta. A mola
  /// passa um pouco de 0 e de 1 antes de assentar.
  Widget _build(BuildContext context, double t, double labelScale) {
    final half = (destinations.length / 2).ceil();
    final barHeight = lerpDouble(_barHeight, _compactBarHeight, t)!;
    final scanSize = lerpDouble(_scanSize, _compactScanSize, t)!;
    final scanLift = lerpDouble(_scanLift, _compactScanLift, t)!;
    final labelFactor = clampDouble(1 - t, 0, 1);
    // Onde o botão fica dentro da caixa da barra: no topo na barra normal.
    final scanTop = _barHeight + _scanLift - barHeight - scanLift;

    Widget destination(int index) =>
        _destination(index, labelFactor: labelFactor, labelScale: labelScale, balloonGap: scanLift + _balloonGap);

    final onScanLongPress = this.onScanLongPress;
    final bar = SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(_margin, 0, _margin, _margin),
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
              child: _glass(
                context,
                Row(
                  children: [
                    for (var i = 0; i < half; i++) destination(i),
                    const SizedBox(width: _scanGap),
                    for (var i = half; i < destinations.length; i++) destination(i),
                  ],
                ),
              ),
            ),
            Positioned(
              top: scanTop,
              child: _ScanButton(
                label: scanLabel,
                size: scanSize,
                breath: ringBreath,
                onPressed: onScan,
                // O menu põe o "×" onde o botão fica na barra normal, que é
                // como a barra volta ao abrir o menu.
                onLongPress: onScanLongPress == null
                    ? null
                    : (rect) => onScanLongPress(
                        Rect.fromLTWH(rect.center.dx - _scanSize / 2, rect.top - scanTop, _scanSize, _scanSize),
                      ),
                longPressLabel: scanLongPressLabel,
              ),
            ),
          ],
        ),
      ),
    );

    final above = this.above;
    // Sempre numa coluna: com ou sem [above], a barra é a mesma, e o anel
    // não recomeça quando a barra da compra entra ou sai.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Só no desenho (e no toque), sem mudar o layout.
        if (above != null) Transform.translate(offset: Offset(0, _barHeight - barHeight), child: above),
        bar,
      ],
    );
  }

  /// A barra com o bipar flutuando acima dela, à direita, para a letra acima
  /// de 160%. Não encolhe: os rótulos estão ali porque a pessoa precisa deles.
  Widget _buildFloating(BuildContext context, double labelScale) {
    // A pílula cresce com o rótulo, a partir dos 68 px de sempre.
    final pillHeight = math
        .max(_barHeight, 2 * _pillPadding + _indicatorHeight + _labelGap + _labelLineHeight * labelScale + 1)
        .ceilToDouble();
    final above = this.above;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // O bipar faz parte da caixa da barra: o espaço que ela reserva no
        // layout inclui o botão, e o fim das telas não fica atrás dele. Ao
        // lado do botão, o toque passa para o conteúdo. Quando [above] fica
        // no lugar dele, o espaço sai junto.
        if (above == null || !aboveReplacesScan)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: _margin + _floatingInset, bottom: _floatingGap),
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: _ScanButton(
                label: scanLabel,
                size: _scanSize,
                breath: ringBreath,
                onPressed: onScan,
                onLongPress: onScanLongPress,
                longPressLabel: scanLongPressLabel,
              ),
            ),
          ),
        ?above,
        SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(_margin, 0, _margin, _margin),
          child: SizedBox(
            height: pillHeight,
            child: _glass(
              context,
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: _floatingPadding),
                child: Row(
                  children: [
                    for (var i = 0; i < destinations.length; i++)
                      _destination(i, labelFactor: 1, labelScale: labelScale, balloonGap: _floatingGap),
                  ],
                ),
              ),
            ),
          ),
        ),
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

class _Destination extends StatefulWidget {
  const _Destination({
    required this.destination,
    required this.selected,
    required this.labelFactor,
    required this.labelScale,
    required this.balloonGap,
    required this.onTap,
  });

  final ScanNavDestination destination;
  final bool selected;

  /// Quanto do rótulo aparece: 1 na barra normal, 0 na compacta. Sumido, ele
  /// continua no rótulo acessível.
  final double labelFactor;

  /// A escala do rótulo, a mesma nos quatro destinos ([ScanNavBar._fitLabels]).
  final double labelScale;

  /// Quanto o balão do rótulo grande fica acima do topo da pílula.
  final double balloonGap;
  final VoidCallback onTap;

  @override
  State<_Destination> createState() => _DestinationState();
}

class _DestinationState extends State<_Destination> {
  final _balloon = OverlayPortalController();

  void _hold() {
    HapticFeedback.selectionClick();
    _balloon.show();
  }

  void _release() {
    if (_balloon.isShowing) _balloon.hide();
  }

  /// O balão, centrado na tela e logo acima da barra.
  Widget _buildBalloon(BuildContext overlayContext) {
    final box = context.findRenderObject();
    final overlay = Overlay.of(context).context.findRenderObject();
    if (box is! RenderBox || overlay is! RenderBox || !box.hasSize) return const SizedBox.shrink();
    final top = box.localToGlobal(Offset.zero, ancestor: overlay).dy;
    return Positioned(
      left: BipaSpacing.s4,
      right: BipaSpacing.s4,
      bottom: overlay.size.height - top + widget.balloonGap,
      child: Center(
        child: _LabelBalloon(
          icon: widget.selected ? widget.destination.selectedIcon : widget.destination.icon,
          label: widget.destination.label,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final selected = widget.selected;
    final labelFactor = widget.labelFactor;
    return Semantics(
      button: true,
      selected: selected,
      label: widget.destination.label,
      excludeSemantics: true,
      // excludeSemantics descarta a ação do InkResponse: ela vai aqui. O
      // balão não entra: o leitor de tela já diz o rótulo.
      onTap: widget.onTap,
      child: OverlayPortal(
        controller: _balloon,
        overlayChildBuilder: _buildBalloon,
        child: GestureDetector(
          // Segurar mostra o rótulo grande enquanto o dedo fica.
          onLongPressStart: (_) => _hold(),
          onLongPressEnd: (_) => _release(),
          onLongPressCancel: _release,
          child: InkResponse(
            onTap: widget.onTap,
            radius: 36,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: BipaMotion.slow,
                  curve: BipaMotion.spring,
                  width: selected ? 52 : 32,
                  height: ScanNavBar._indicatorHeight,
                  decoration: ShapeDecoration(
                    shape: const StadiumBorder(),
                    color: selected ? colors.brandSoft : Colors.transparent,
                  ),
                  child: Icon(
                    selected ? widget.destination.selectedIcon : widget.destination.icon,
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
                        padding: const EdgeInsets.fromLTRB(
                          ScanNavBar._labelPadding,
                          ScanNavBar._labelGap,
                          ScanNavBar._labelPadding,
                          0,
                        ),
                        child: Text(
                          widget.destination.label,
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          // A escala já leva em conta a letra do aparelho.
                          textScaler: TextScaler.linear(widget.labelScale),
                          style: ScanNavBar._labelStyle(context, selected: selected),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// O rótulo grande de um destino, num balão de vidro (quadro
/// "NavLetraGrande", `.big-label`).
class _LabelBalloon extends StatelessWidget {
  const _LabelBalloon({required this.icon, required this.label});

  final IconData icon;
  final String label;

  static const _shape = RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(BipaRadius.lg)));

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return IgnorePointer(
      child: ExcludeSemantics(
        child: DecoratedBox(
          key: ScanNavBar.balloonKey,
          decoration: ShapeDecoration(
            shape: _shape,
            shadows: [BoxShadow(color: colors.ink.withValues(alpha: 0.12), blurRadius: 24, offset: const Offset(0, 8))],
          ),
          child: ClipPath(
            clipper: const ShapeBorderClipper(shape: _shape),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: ScanNavBar._blur, sigmaY: ScanNavBar._blur),
              child: ColoredBox(
                color: colors.surfaceGlass,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: BipaSpacing.s6, vertical: BipaSpacing.s4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 40, color: colors.ink),
                      const SizedBox(height: 6),
                      // Já é grande (28 px): crescer com a letra do aparelho
                      // faria o balão passar da tela.
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        textScaler: TextScaler.noScaling,
                        style: BipaText.body.copyWith(
                          fontSize: 28,
                          height: 34 / 28,
                          fontWeight: FontWeight.w700,
                          color: colors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScanButton extends StatefulWidget {
  const _ScanButton({
    required this.label,
    required this.size,
    required this.breath,
    required this.onPressed,
    this.onLongPress,
    this.longPressLabel,
  });

  final String label;
  final ScanRingBreath breath;

  /// 64 px, ou 56 na barra compacta.
  final double size;
  final VoidCallback onPressed;

  /// Recebe onde o botão está na tela, em coordenadas globais.
  final ValueChanged<Rect>? onLongPress;
  final String? longPressLabel;

  @override
  State<_ScanButton> createState() => _ScanButtonState();
}

class _ScanButtonState extends State<_ScanButton> with SingleTickerProviderStateMixin {
  /// Um ciclo do anel que respira (`bipa-breathe`: 2,4 s).
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..addStatusListener(_onBreathStatus);

  /// Quantas respirações quando a barra aparece (H16): 4,8 s.
  static const _breathsOnAppear = 2;

  /// O anel cresce até 1,22 vez o botão enquanto some de 35% a 0 de opacidade.
  static const _ringScale = 1.22;
  static const _ringOpacity = 0.35;

  /// Movimento reduzido: o anel não respira e nem chega a ser desenhado.
  bool? _still;

  /// O anel está à vista. Parado, ele sai da árvore e a barra não pede
  /// quadros.
  bool _breathing = false;

  /// Os tickers da barra: desligados enquanto outra tela a cobre (a câmera,
  /// por exemplo). Quando voltam, a barra apareceu de novo.
  ValueListenable<TickerModeData>? _tickerMode;

  /// O app voltando do fundo também faz a barra aparecer de novo.
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _onAppear);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tickerMode = TickerMode.getValuesNotifier(context);
    if (tickerMode != _tickerMode) {
      _tickerMode?.removeListener(_onTickerModeChanged);
      _tickerMode = tickerMode..addListener(_onTickerModeChanged);
    }
    final still = MediaQuery.disableAnimationsOf(context);
    if (still != _still) {
      _still = still;
      _appear();
    }
  }

  @override
  void didUpdateWidget(_ScanButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.breath == oldWidget.breath || _still!) return;
    switch (widget.breath) {
      // A casa e a lista ficaram vazias: o convite começa, ou continua do
      // ponto em que estava.
      case ScanRingBreath.endless:
        _breathing = true;
        _breath.repeat();
      // Com o primeiro item, ou com a compra, o ciclo em curso termina e o
      // anel para, sem sumir no meio da respiração.
      case ScanRingBreath.twice || ScanRingBreath.still:
        if (_breath.isAnimating) _breath.forward();
    }
  }

  @override
  void dispose() {
    _tickerMode?.removeListener(_onTickerModeChanged);
    _lifecycle.dispose();
    _breath.dispose();
    super.dispose();
  }

  void _onTickerModeChanged() {
    if (_tickerMode!.value.enabled) _onAppear();
  }

  /// A barra voltou à vista: o anel respira como se ela tivesse aparecido
  /// agora.
  void _onAppear() {
    if (!mounted) return;
    setState(_appear);
  }

  /// Começa como a barra que acaba de aparecer: duas respirações, sem fim ou
  /// parado. Sem fim, se já respirava, continua de onde estava.
  void _appear() {
    final breath = _still! ? ScanRingBreath.still : widget.breath;
    switch (breath) {
      case ScanRingBreath.twice:
        _breathing = true;
        _breath
          ..reset()
          ..repeat(count: _breathsOnAppear);
      case ScanRingBreath.endless:
        _breathing = true;
        if (!_breath.isAnimating) _breath.repeat();
      case ScanRingBreath.still:
        _breathing = false;
        _breath.stop();
    }
  }

  /// As respirações acabaram: o anel sai.
  void _onBreathStatus(AnimationStatus status) {
    if (status.isCompleted && mounted) setState(() => _breathing = false);
  }

  /// O anel em [t], de 0 a 1 no ciclo. Como no CSS, a curva vale para cada
  /// metade: de 0 a 50% o anel cresce e some, de 50 a 100% encolhe e volta.
  static ({double scale, double opacity}) _ringAt(double t) {
    final growing = t < 0.5;
    final p = BipaMotion.standard.transform(growing ? t * 2 : (t - 0.5) * 2);
    final k = growing ? p : 1 - p;
    return (scale: lerpDouble(1, _ringScale, k)!, opacity: lerpDouble(_ringOpacity, 0, k)!);
  }

  /// Onde o botão está na tela.
  Rect _globalRect() {
    final box = context.findRenderObject()! as RenderBox;
    return box.localToGlobal(Offset.zero) & box.size;
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
        if (_breathing)
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
          onLongPress: onLongPress == null ? null : () => onLongPress(_globalRect()),
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
                      onLongPress(_globalRect());
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
