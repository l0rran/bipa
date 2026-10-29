import 'package:bipa/core/crash_reporting/crash_reporting.dart';
import 'package:bipa/core/crash_reporting/file_crash_reporting_consent_store.dart';
import 'package:bipa/core/crash_reporting/sentry_crash_reporter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// Onde a resposta fica guardada. O `main` troca pela instância que já leu
/// a resposta na abertura.
final crashReportingConsentStoreProvider = Provider<CrashReportingConsentStore>(
  (ref) => FileCrashReportingConsentStore(getApplicationSupportDirectory),
);

/// O serviço de relatório. O `main` troca pela instância já iniciada.
final crashReporterProvider = Provider<CrashReporter>((ref) => SentryCrashReporter.fromEnvironment());

/// A resposta lida na abertura do app, antes do `runApp`.
final initialCrashReportingConsentProvider = Provider<CrashReportingConsent>((ref) => CrashReportingConsent.unasked);

/// Se este build pode mandar relatórios. Sem DSN, a interface não pergunta.
final crashReportingAvailableProvider = Provider<bool>((ref) => ref.watch(crashReporterProvider).isAvailable);

final setCrashReportingConsentProvider = Provider<SetCrashReportingConsent>(
  (ref) => SetCrashReportingConsent(ref.watch(crashReportingConsentStoreProvider), ref.watch(crashReporterProvider)),
);

/// A resposta da pessoa, para a pergunta e o interruptor dos Ajustes
/// (ADR 0025). Mudar liga ou desliga o relatório na hora.
final crashReportingConsentProvider = NotifierProvider<CrashReportingConsentController, CrashReportingConsent>(
  CrashReportingConsentController.new,
);

class CrashReportingConsentController extends Notifier<CrashReportingConsent> {
  @override
  CrashReportingConsent build() => ref.watch(initialCrashReportingConsentProvider);

  Future<void> grant() => _set(granted: true);

  /// Recusar a pergunta ou revogar depois: as duas coisas são a mesma.
  Future<void> deny() => _set(granted: false);

  Future<void> _set({required bool granted}) async {
    await ref.read(setCrashReportingConsentProvider)(granted: granted);
    state = granted ? CrashReportingConsent.granted : CrashReportingConsent.denied;
  }
}
