import 'dart:async';

import 'package:bipa/core/design_system/bipa_metrics.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/design_system/bipa_typography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Quanto tempo o aviso com ação fica na tela: a linha do tempo do
/// `bipa-toast` esvazia em 4 s, e depois disso o registro fica.
const bipaToastDuration = Duration(seconds: 4);

/// A regra do tempo do `bipa-toast`: quanto tempo um aviso fica antes de sair
/// sozinho, ou `null` quando ele espera a pessoa. Vale para o
/// [showBipaToast] e para os avisos que não são snackbar, como o do visor da
/// câmera ([BipaNoticeTimer]).
///
/// Com o TalkBack ou outro leitor de tela
/// ([MediaQueryData.accessibleNavigation]), o aviso com ação não sai
/// sozinho: fica até a pessoa agir, dispensá-lo ou outro aviso tomar o
/// lugar, para dar tempo de chegar até a ação (WCAG 2.2.1).
Duration? bipaToastTimeout(BuildContext context, {required bool hasAction, Duration duration = bipaToastDuration}) {
  final screenReader = MediaQuery.maybeAccessibleNavigationOf(context) ?? false;
  if (hasAction && screenReader) return null;
  return duration;
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
/// No Flutter 3.47 um `SnackBar` com ação fica na tela até alguém tocar
/// (`persist` vem verdadeiro). Aqui o aviso com ação some sozinho depois de
/// [duration], como no design system, exceto quando a regra de
/// [bipaToastTimeout] pede que ele espere a pessoa (com leitor de tela); aí
/// a linha do tempo não aparece.
///
/// Devolve o controle do aviso, para quem precisa saber quando ele sai.
ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showBipaToast(
  ScaffoldMessengerState messenger,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = bipaToastDuration,
}) {
  final hasAction = actionLabel != null && onAction != null;
  final timeout = bipaToastTimeout(messenger.context, hasAction: hasAction, duration: duration);
  final started = ValueNotifier(false);
  messenger.hideCurrentSnackBar();
  final controller = messenger.showSnackBar(
    SnackBar(
      padding: EdgeInsets.zero,
      duration: timeout ?? duration,
      persist: timeout == null,
      // A linha do tempo anda junto com o relógio do ScaffoldMessenger, que
      // só começa a contar quando o aviso termina de entrar.
      onVisible: () => started.value = true,
      content: BipaToast(
        message: message,
        actionLabel: hasAction ? actionLabel : null,
        onAction: hasAction
            ? () {
                messenger.hideCurrentSnackBar(reason: SnackBarClosedReason.action);
                onAction();
              }
            : null,
        timer: hasAction ? timeout : null,
        started: started,
      ),
    ),
  );
  return controller;
}

/// O conteúdo do aviso: o texto, a ação e, embaixo, a linha do tempo.
/// O fundo, o raio e a sombra vêm do `snackBarTheme` do [BipaTheme].
class BipaToast extends StatefulWidget {
  const BipaToast({required this.message, this.actionLabel, this.onAction, this.timer, this.started, super.key});

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Em quanto tempo a linha do tempo esvazia; `null` não a mostra.
  final Duration? timer;

  /// Quando a linha começa a esvaziar; sem ele, ela começa ao aparecer.
  final ValueListenable<bool>? started;

  @override
  State<BipaToast> createState() => _BipaToastState();
}

class _BipaToastState extends State<BipaToast> with SingleTickerProviderStateMixin {
  /// A linha é um relógio, não decoração: com "Remover animações", o
  /// Flutter encurtaria a animação comum para uma fração do tempo, e ela
  /// esvaziaria antes do aviso sair (H14).
  late final AnimationController _timeLeft = AnimationController(
    vsync: this,
    value: 1,
    duration: widget.timer ?? Duration.zero,
    animationBehavior: AnimationBehavior.preserve,
  );
  var _acted = false;

  @override
  void initState() {
    super.initState();
    final started = widget.started;
    if (started == null) {
      _run();
    } else {
      started.addListener(_onStarted);
      _onStarted();
    }
  }

  void _onStarted() {
    if (widget.started?.value ?? false) _run();
  }

  void _run() {
    if (widget.timer != null && !_timeLeft.isAnimating && _timeLeft.value == 1) _timeLeft.reverse();
  }

  @override
  void dispose() {
    widget.started?.removeListener(_onStarted);
    _timeLeft.dispose();
    super.dispose();
  }

  void _act() {
    // Como o SnackBarAction: dois toques rápidos desfazem uma vez só.
    if (_acted) return;
    _acted = true;
    widget.onAction?.call();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final actionLabel = widget.actionLabel;
    final hasAction = actionLabel != null && widget.onAction != null;
    // Com "Remover animações", a linha sai, como o anel do bipar: o estado
    // final de algo que esvazia é não estar lá. O tempo continua valendo.
    final showTimer = widget.timer != null && !MediaQuery.disableAnimationsOf(context);
    return Stack(
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
                  style: BipaText.label.copyWith(fontWeight: FontWeight.w600, height: 20 / 14, color: colors.ground),
                ),
              ),
              if (hasAction) ...[
                const SizedBox(width: BipaSpacing.s3),
                TextButton(
                  onPressed: _act,
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
    );
  }
}
