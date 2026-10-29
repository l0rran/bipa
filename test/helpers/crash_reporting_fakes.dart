import 'package:bipa/core/crash_reporting/crash_reporting.dart';

/// Guarda a resposta em memória, sem arquivo.
final class MemoryConsentStore implements CrashReportingConsentStore {
  MemoryConsentStore([this.value = CrashReportingConsent.unasked]);

  CrashReportingConsent value;

  @override
  Future<CrashReportingConsent> read() async => value;

  @override
  Future<void> write(CrashReportingConsent consent) async => value = consent;
}

/// Anota o que foi pedido ao relatório, sem rede. Com [isAvailable] falso,
/// age como um build sem DSN.
final class FakeCrashReporter implements CrashReporter {
  FakeCrashReporter({this.isAvailable = true});

  @override
  final bool isAvailable;

  final calls = <String>[];

  @override
  Future<void> start() async => calls.add('start');

  @override
  Future<void> stop() async => calls.add('stop');
}
