import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// O tempo que a pessoa pediu ao Android para o que some sozinho da tela: o
/// ajuste "Tempo para agir" da Acessibilidade (Android 10 ou mais novo,
/// `AccessibilityManager.getRecommendedTimeoutMillis`). O Flutter não o lê
/// sozinho (H13).
///
/// É um piso: o aviso fica pelo menos esse tempo, e mais se o tempo dele já
/// for maior. Zero quando a pessoa não pediu nada.
@immutable
final class RecommendedTimeouts {
  const RecommendedTimeouts({this.controls = Duration.zero, this.text = Duration.zero});

  /// Para o que tem botão, como o aviso com "Desfazer".
  final Duration controls;

  /// Para o que só tem texto, como o aviso de falha.
  final Duration text;

  /// Nenhum pedido: valem os tempos do design system.
  static const none = RecommendedTimeouts();

  @override
  bool operator ==(Object other) => other is RecommendedTimeouts && other.controls == controls && other.text == text;

  @override
  int get hashCode => Object.hash(controls, text);
}

/// De onde vem o [RecommendedTimeouts]: o Android, ou um falso nos testes.
abstract interface class RecommendedTimeoutsSource {
  /// Nunca falha: sem resposta, devolve [RecommendedTimeouts.none].
  Future<RecommendedTimeouts> read();
}

/// Pergunta ao código nativo do Android (MainActivity), pelo mesmo padrão de
/// canal da notificação ao vivo (ADR 0015).
final class MethodChannelRecommendedTimeouts implements RecommendedTimeoutsSource {
  MethodChannelRecommendedTimeouts([MethodChannel? channel])
    : _channel = channel ?? const MethodChannel('dev.l0rran.bipa/accessibility');

  final MethodChannel _channel;

  @override
  Future<RecommendedTimeouts> read() async {
    if (defaultTargetPlatform != TargetPlatform.android) return RecommendedTimeouts.none;
    try {
      final answer = await _channel.invokeMapMethod<String, Object?>('recommendedTimeouts');
      return RecommendedTimeouts(controls: _millis(answer?['controls']), text: _millis(answer?['text']));
    } on PlatformException catch (error, stack) {
      FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack, library: 'accessibility'));
      return RecommendedTimeouts.none;
    } on MissingPluginException {
      // Testes e plataformas sem o código nativo.
      return RecommendedTimeouts.none;
    }
  }

  static Duration _millis(Object? value) => value is int && value > 0 ? Duration(milliseconds: value) : Duration.zero;
}

/// Dá o [RecommendedTimeouts] a quem está abaixo, como o `MediaQuery` dá o
/// leitor de tela. Fica acima do `MaterialApp`, para o `ScaffoldMessenger`
/// do app também enxergar.
class RecommendedTimeoutsScope extends InheritedWidget {
  const RecommendedTimeoutsScope({required this.timeouts, required super.child, super.key});

  final RecommendedTimeouts timeouts;

  /// O tempo pedido, ou [RecommendedTimeouts.none] fora de um escopo (nos
  /// testes de tela, por exemplo).
  static RecommendedTimeouts of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RecommendedTimeoutsScope>()?.timeouts ?? RecommendedTimeouts.none;

  @override
  bool updateShouldNotify(RecommendedTimeoutsScope oldWidget) => timeouts != oldWidget.timeouts;
}

/// Lê o [RecommendedTimeouts] ao abrir o app e toda vez que ele volta para a
/// frente (a pessoa pode ter mudado o ajuste nesse meio-tempo), e o dá a
/// [child] por um [RecommendedTimeoutsScope].
class RecommendedTimeoutsLoader extends StatefulWidget {
  const RecommendedTimeoutsLoader({required this.child, this.source, super.key});

  final Widget child;

  /// Sem ele, o Android.
  final RecommendedTimeoutsSource? source;

  @override
  State<RecommendedTimeoutsLoader> createState() => _RecommendedTimeoutsLoaderState();
}

class _RecommendedTimeoutsLoaderState extends State<RecommendedTimeoutsLoader> {
  late final RecommendedTimeoutsSource _source = widget.source ?? MethodChannelRecommendedTimeouts();
  late final AppLifecycleListener _lifecycle;
  var _timeouts = RecommendedTimeouts.none;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: () => unawaited(_read()));
    unawaited(_read());
  }

  Future<void> _read() async {
    final timeouts = await _source.read();
    if (mounted && timeouts != _timeouts) setState(() => _timeouts = timeouts);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RecommendedTimeoutsScope(timeouts: _timeouts, child: widget.child);
}
