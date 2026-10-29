import 'dart:async';
import 'dart:math' as math;

import 'package:bipa/core/accessibility/recommended_timeouts.dart';
import 'package:bipa/core/design_system/bipa_metrics.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/design_system/bipa_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Quanto tempo o aviso fica na tela antes de sair sozinho.
enum BipaToastDuration {
  /// O padrão do design system: a linha do tempo do `bipa-toast` esvazia em
  /// 4 s, e depois disso o registro fica.
  short(Duration(seconds: 4)),

  /// Para o Desfazer de ações que mexem em muitos registros de uma vez ou
  /// que não pedem confirmação: tirar os comprados da lista, terminar a
  /// compra, apagar ou mover uma embalagem com os preços (H13). É o "longo"
  /// do Material (`SnackbarDuration.Long`, 10 s).
  long(Duration(seconds: 10));

  const BipaToastDuration(this.time);

  final Duration time;
}

/// A regra do tempo do `bipa-toast`: quanto tempo um aviso fica antes de sair
/// sozinho, ou `null` quando ele espera a pessoa. Vale para o
/// [showBipaToast] e para os avisos que não são snackbar, como o do visor da
/// câmera ([BipaNoticeTimer]).
///
/// Com o TalkBack ou outro leitor de tela
/// ([MediaQueryData.accessibleNavigation]), o aviso com ação não sai
/// sozinho: fica até a pessoa agir, dispensá-lo ou outro aviso tomar o
/// lugar, para dar tempo de chegar até a ação (WCAG 2.2.1). Fora isso, o
/// aviso fica [duration] ou o "Tempo para agir" que a pessoa pediu ao
/// Android ([RecommendedTimeouts]), o que for maior (H13).
Duration? bipaToastTimeout(BuildContext context, {required bool hasAction, Duration? duration}) {
  final screenReader = MediaQuery.maybeAccessibleNavigationOf(context) ?? false;
  if (hasAction && screenReader) return null;
  final asked = RecommendedTimeoutsScope.of(context);
  final floor = hasAction ? asked.controls : asked.text;
  final own = duration ?? BipaToastDuration.short.time;
  return own > floor ? own : floor;
}

/// O relógio de um aviso que não é snackbar (o do visor da câmera), com a
/// mesma regra do `bipa-toast` ([bipaToastTimeout]).
final class BipaNoticeTimer {
  Timer? _timer;

  /// Começa a contar de novo para o aviso que acabou de aparecer e chama
  /// [onTimeout] quando ele deve sair. Devolve `false` quando o aviso espera
  /// a pessoa e não sai sozinho.
  bool start(
    BuildContext context, {
    required bool hasAction,
    required Duration duration,
    required VoidCallback onTimeout,
  }) {
    cancel();
    final timeout = bipaToastTimeout(context, hasAction: hasAction, duration: duration);
    if (timeout == null) return false;
    _timer = Timer(timeout, onTimeout);
    return true;
  }

  /// Para de contar: o aviso saiu, ou a pessoa está agindo nele.
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }
}

/// Mostra o aviso do design system (`bipa-toast`, o mesmo do "Bipou!") no
/// lugar do que estiver na tela: [message] em `ground` sobre `ink`, com raio
/// `radius-lg`, e, com [actionLabel] e [onAction], a ação ("Desfazer") em
/// `price` e a linha do tempo que esvazia em [duration].
///
/// O tempo segue a regra de [bipaToastTimeout]: com leitor de tela, o aviso
/// com ação espera a pessoa (e a linha do tempo não aparece); fora isso, ele
/// fica [duration] ou o "Tempo para agir" do Android, o que for maior.
///
/// O aviso com ação tem relógio próprio (o do `ScaffoldMessenger` não para):
/// enquanto o dedo está sobre o aviso, o tempo para, e volta a correr de onde
/// parou quando o dedo sai (H13). O aviso só de texto usa o relógio do
/// `ScaffoldMessenger`.
///
/// Devolve o controle do aviso, para quem precisa saber quando ele sai.
ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showBipaToast(
  ScaffoldMessengerState messenger,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
  BipaToastDuration duration = BipaToastDuration.short,
}) {
  final hasAction = actionLabel != null && onAction != null;
  final timeout = bipaToastTimeout(messenger.context, hasAction: hasAction, duration: duration.time);
  var closed = false;
  final clock = hasAction && timeout != null
      ? BipaToastClock(
          timeout,
          onTimeout: () {
            if (!closed) messenger.hideCurrentSnackBar(reason: SnackBarClosedReason.timeout);
          },
        )
      : null;
  var acted = false;
  messenger.hideCurrentSnackBar();
  final controller = messenger.showSnackBar(
    SnackBar(
      padding: EdgeInsets.zero,
      duration: timeout ?? duration.time,
      // Com ação, quem tira o aviso é o relógio dele, ou a pessoa.
      persist: hasAction,
      // O relógio só começa quando o aviso termina de entrar.
      onVisible: clock?.start,
      content: BipaToast(
        message: message,
        actionLabel: hasAction ? actionLabel : null,
        onAction: hasAction
            ? () {
                // Como o SnackBarAction: dois toques rápidos desfazem uma vez só.
                if (acted) return;
                acted = true;
                messenger.hideCurrentSnackBar(reason: SnackBarClosedReason.action);
                onAction();
              }
            : null,
        clock: clock,
      ),
    ),
  );
  unawaited(controller.closed.whenComplete(() => closed = true));
  return controller;
}

/// O relógio de um aviso com ação, dividido pelas cópias dele: o
/// `ScaffoldMessenger` desenha o aviso em cada `Scaffold` de cima (duas telas
/// durante a transição, ou a tela e uma folha), e cada cópia anda a sua linha
/// do tempo. O dedo sobre uma delas para todas, e a primeira que chega ao fim
/// tira o aviso.
final class BipaToastClock extends ChangeNotifier {
  BipaToastClock(this.duration, {required VoidCallback onTimeout}) : _onTimeout = onTimeout;

  /// Em quanto tempo o aviso sai, sem contar as pausas.
  final Duration duration;
  final VoidCallback _onTimeout;

  var _started = false;
  var _holds = 0;
  var _timeLeft = 1.0;
  var _done = false;

  /// Se o tempo está correndo: o aviso já entrou e ninguém está tocando nele.
  bool get running => _started && _holds == 0 && !_done;

  /// Quanto ainda falta, de 0 a 1: a cópia que aparece no meio do caminho
  /// começa daqui.
  double get timeLeft => _timeLeft;

  /// O aviso terminou de entrar.
  void start() {
    if (_started) return;
    _started = true;
    notifyListeners();
  }

  /// Um dedo encostou no aviso.
  void hold() {
    _holds++;
    notifyListeners();
  }

  /// O dedo saiu do aviso.
  void release() {
    if (_holds == 0) return;
    _holds--;
    notifyListeners();
  }

  void _tick(double timeLeft) {
    if (timeLeft < _timeLeft) _timeLeft = timeLeft;
  }

  void _finish() {
    if (_done) return;
    _done = true;
    _onTimeout();
  }
}

/// Faz os avisos aparecerem por cima de uma folha modal, e não atrás dela
/// (H15). Vai em volta do conteúdo da folha, no `builder` do
/// `showModalBottomSheet`.
///
/// O aviso é desenhado pelo `Scaffold` da tela; uma folha aberta sobre a
/// tela o cobre. Aqui, um `Scaffold` transparente do tamanho da folha, por
/// cima dela, se registra no `ScaffoldMessenger` do app e desenha uma cópia
/// do aviso no pé da folha. Quem chama continua usando
/// `ScaffoldMessenger.of(context)`, e o aviso continua na tela quando a
/// folha fecha. Os toques passam direto para a folha, exceto os que caem no
/// aviso.
///
/// Numa folha aberta dentro de uma aba, o `Scaffold` da casca (o da
/// navegação) já desenha o aviso por cima da folha, e o daqui fica quieto: o
/// `ScaffoldMessenger` só desenha no `Scaffold` de fora.
class BipaSheetToasts extends StatelessWidget {
  const BipaSheetToasts({required this.child, super.key});

  final Widget child;

  /// A altura mínima do Scaffold da folha: o bastante para o aviso, com letra
  /// grande, sem o Flutter acusar o aviso fora da tela.
  static const _minToastRoom = 200.0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        child,
        Positioned.fill(
          child: _ToastHitsOnly(
            // Numa folha baixa, o Scaffold sobra para cima, para o aviso
            // caber; ele fica no pé, dentro da folha.
            child: LayoutBuilder(
              builder: (context, constraints) {
                final height = math.max(constraints.maxHeight, _minToastRoom);
                return OverflowBox(
                  minHeight: height,
                  maxHeight: height,
                  alignment: Alignment.bottomCenter,
                  // A folha já sobe com o teclado: o Scaffold não sobe de novo.
                  child: MediaQuery.removeViewInsets(
                    context: context,
                    removeBottom: true,
                    child: const Scaffold(backgroundColor: Colors.transparent, resizeToAvoidBottomInset: false),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Só aceita o toque que cai num aviso ([_ToastMarker]); o resto passa para o
/// que está embaixo.
class _ToastHitsOnly extends SingleChildRenderObjectWidget {
  const _ToastHitsOnly({required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderToastHitsOnly();
}

class _RenderToastHitsOnly extends RenderProxyBox {
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final child = this.child;
    if (child == null || !size.contains(position)) return false;
    // Testa à parte para decidir; só então testa de verdade, com as
    // transformações de cada nível no resultado.
    final probe = BoxHitTestResult();
    if (!child.hitTest(probe, position: position)) return false;
    if (!probe.path.any((entry) => entry.target is _RenderToastMarker)) return false;
    return super.hitTest(result, position: position);
  }
}

/// Marca a área do aviso, para o [_ToastHitsOnly].
class _ToastMarker extends SingleChildRenderObjectWidget {
  const _ToastMarker({required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderToastMarker();
}

class _RenderToastMarker extends RenderProxyBox {}

/// O conteúdo do aviso: o texto, a ação e, embaixo, a linha do tempo.
/// O fundo, o raio e a sombra vêm do `snackBarTheme` do [BipaTheme].
class BipaToast extends StatefulWidget {
  const BipaToast({required this.message, this.actionLabel, this.onAction, this.clock, super.key});

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// O relógio do aviso com ação, que a linha do tempo mostra; `null` não a
  /// mostra (o aviso só de texto, ou o que espera a pessoa).
  final BipaToastClock? clock;

  @override
  State<BipaToast> createState() => _BipaToastState();
}

class _BipaToastState extends State<BipaToast> with SingleTickerProviderStateMixin {
  /// A linha é um relógio, não decoração: com "Remover animações", o
  /// Flutter encurtaria a animação comum para uma fração do tempo, e ela
  /// esvaziaria antes do aviso sair (H14).
  late final AnimationController _timeLeft = AnimationController(
    vsync: this,
    value: widget.clock?.timeLeft ?? 1,
    duration: widget.clock?.duration ?? Duration.zero,
    animationBehavior: AnimationBehavior.preserve,
  );

  /// Os dedos desta cópia sobre o aviso, para devolver se ela sair antes.
  var _holds = 0;

  @override
  void initState() {
    super.initState();
    final clock = widget.clock;
    if (clock == null) return;
    clock.addListener(_follow);
    _timeLeft
      ..addListener(() => clock._tick(_timeLeft.value))
      ..addStatusListener((status) {
        if (status.isDismissed) clock._finish();
      });
    _follow();
  }

  /// Anda ou para junto com o relógio.
  void _follow() {
    final clock = widget.clock;
    if (clock == null) return;
    if (clock.running) {
      if (!_timeLeft.isAnimating) unawaited(_timeLeft.reverse());
    } else {
      _timeLeft.stop();
    }
  }

  void _hold() {
    if (widget.clock == null) return;
    _holds++;
    widget.clock!.hold();
  }

  void _release() {
    if (_holds == 0) return;
    _holds--;
    widget.clock!.release();
  }

  @override
  void dispose() {
    final clock = widget.clock;
    if (clock != null) {
      clock.removeListener(_follow);
      for (; _holds > 0; _holds--) {
        clock.release();
      }
    }
    _timeLeft.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final actionLabel = widget.actionLabel;
    final onAction = widget.onAction;
    final hasAction = actionLabel != null && onAction != null;
    // Com "Remover animações", a linha sai, como o anel do bipar: o estado
    // final de algo que esvazia é não estar lá. O tempo continua valendo.
    final showTimer = widget.clock != null && !MediaQuery.disableAnimationsOf(context);
    return _ToastMarker(
      child: Listener(
        // O dedo sobre o aviso para o tempo, inclusive no caminho até o
        // Desfazer ou ao arrastar para dispensar.
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => _hold(),
        onPointerUp: (_) => _release(),
        onPointerCancel: (_) => _release(),
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                BipaSpacing.s4,
                BipaSpacing.s3,
                hasAction ? BipaSpacing.s2 : BipaSpacing.s4,
                BipaSpacing.s3,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.message,
                      style: BipaText.label.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 20 / 14,
                        color: colors.ground,
                      ),
                    ),
                  ),
                  if (hasAction) ...[
                    const SizedBox(width: BipaSpacing.s3),
                    TextButton(
                      onPressed: onAction,
                      style: TextButton.styleFrom(
                        foregroundColor: colors.price,
                        textStyle: BipaText.label.copyWith(fontWeight: FontWeight.w800),
                        shape: const StadiumBorder(),
                        // O alvo de toque tem 48 de altura, mesmo com o aviso baixo.
                        minimumSize: const Size(48, 48),
                        padding: const EdgeInsets.symmetric(horizontal: BipaSpacing.s3),
                      ),
                      child: Text(actionLabel),
                    ),
                  ],
                ],
              ),
            ),
            if (showTimer)
              PositionedDirectional(
                start: 0,
                end: 0,
                bottom: 0,
                child: ExcludeSemantics(
                  child: AnimatedBuilder(
                    animation: _timeLeft,
                    builder: (context, _) => Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: FractionallySizedBox(
                        key: const ValueKey('bipa-toast-timer'),
                        widthFactor: _timeLeft.value,
                        child: SizedBox(height: 3, child: ColoredBox(color: colors.price)),
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
