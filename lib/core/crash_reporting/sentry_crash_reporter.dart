import 'package:bipa/core/crash_reporting/crash_reporting.dart';
import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// O relatório de falhas pelo Sentry (ADR 0025). Só é iniciado com DSN e
/// com o consentimento da pessoa; o DSN vem do build, nunca do repositório.
final class SentryCrashReporter implements CrashReporter {
  SentryCrashReporter(this._dsn);

  /// Lê o DSN de `--dart-define=SENTRY_DSN=...`. Sem ele, o relatório nunca
  /// é iniciado.
  factory SentryCrashReporter.fromEnvironment() => SentryCrashReporter(const String.fromEnvironment('SENTRY_DSN'));

  final String _dsn;

  /// As operações em fila, para ligar e desligar seguidos não se cruzarem.
  Future<void> _queue = Future.value();
  bool _started = false;

  @override
  bool get isAvailable => _dsn.isNotEmpty;

  @override
  Future<void> start() => _enqueue(() async {
    if (!isAvailable || _started) return;
    try {
      await SentryFlutter.init((options) => configure(options, _dsn));
      _started = true;
    } on Object catch (error, stackTrace) {
      // Falhar ao ligar o relatório não pode impedir o app de abrir.
      debugPrint('SentryCrashReporter: $error\n$stackTrace');
    }
  });

  @override
  Future<void> stop() => _enqueue(() async {
    if (!_started) return;
    await Sentry.close();
    _started = false;
  });

  Future<void> _enqueue(Future<void> Function() operation) => _queue = _queue.then((_) => operation());

  /// As opções do Sentry: nada de dado pessoal, nada de captura de tela,
  /// de toques ou de desempenho; só a falha.
  @visibleForTesting
  static void configure(SentryFlutterOptions options, String dsn) {
    options
      ..dsn = dsn
      ..sendDefaultPii = false
      ..attachScreenshot = false
      ..attachViewHierarchy = false
      ..tracesSampleRate = null
      ..enableAutoPerformanceTracing = false
      ..enableUserInteractionBreadcrumbs = false
      ..enableUserInteractionTracing = false
      ..enablePrintBreadcrumbs = false
      ..enableAutoNativeBreadcrumbs = false
      ..enableAutoSessionTracking = false;
    options.replay
      ..sessionSampleRate = 0
      ..onErrorSampleRate = 0;
  }
}
