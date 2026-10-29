import 'package:bipa/core/crash_reporting/sentry_crash_reporter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() {
  group('sem DSN', () {
    test('não está disponível e não inicia o Sentry', () async {
      final reporter = SentryCrashReporter('');
      expect(reporter.isAvailable, isFalse);

      await reporter.start();
      expect(Sentry.isEnabled, isFalse);

      await reporter.stop();
      expect(Sentry.isEnabled, isFalse);
    });

    test('o build dos testes não tem DSN', () {
      expect(SentryCrashReporter.fromEnvironment().isAvailable, isFalse);
    });
  });

  test('com DSN, está disponível', () {
    expect(SentryCrashReporter('https://chave@o0.ingest.sentry.io/0').isAvailable, isTrue);
  });

  test('as opções não mandam dado pessoal nem capturam a tela', () {
    final options = SentryFlutterOptions();
    SentryCrashReporter.configure(options, 'https://chave@o0.ingest.sentry.io/0');

    expect(options.dsn, 'https://chave@o0.ingest.sentry.io/0');
    expect(options.sendDefaultPii, isFalse);
    expect(options.attachScreenshot, isFalse);
    expect(options.attachViewHierarchy, isFalse);
    expect(options.tracesSampleRate, isNull);
    expect(options.enableAutoPerformanceTracing, isFalse);
    expect(options.enableUserInteractionBreadcrumbs, isFalse);
    expect(options.enableUserInteractionTracing, isFalse);
    expect(options.enablePrintBreadcrumbs, isFalse);
    expect(options.enableAutoNativeBreadcrumbs, isFalse);
    expect(options.enableAutoSessionTracking, isFalse);
    expect(options.replay.sessionSampleRate, 0);
    expect(options.replay.onErrorSampleRate, 0);
  });
}
