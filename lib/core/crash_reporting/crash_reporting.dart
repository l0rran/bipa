/// A resposta da pessoa à pergunta do relatório de falhas (ADR 0025).
enum CrashReportingConsent {
  /// Ainda não perguntamos: a interface pode perguntar.
  unasked,

  /// Aceitou: o relatório liga, se o build tiver DSN.
  granted,

  /// Recusou ou revogou: nada é coletado nem enviado.
  denied,
}

/// Onde a resposta fica guardada, no aparelho.
abstract interface class CrashReportingConsentStore {
  /// A resposta guardada; [CrashReportingConsent.unasked] se não houver
  /// nenhuma ou se ela não puder ser lida.
  Future<CrashReportingConsent> read();

  Future<void> write(CrashReportingConsent consent);
}

/// O serviço que manda as falhas para fora do aparelho.
abstract interface class CrashReporter {
  /// Se este build pode mandar relatórios (tem DSN). Sem isso, [start] não
  /// faz nada e a interface não deve perguntar.
  bool get isAvailable;

  /// Começa a coletar e mandar falhas. Chamar de novo não faz nada.
  Future<void> start();

  /// Para de coletar e mandar. Chamar sem ter começado não faz nada.
  Future<void> stop();
}

/// Na abertura do app: liga o relatório se a pessoa já aceitou e devolve a
/// resposta guardada, para a interface.
Future<CrashReportingConsent> startCrashReportingIfGranted(
  CrashReportingConsentStore store,
  CrashReporter reporter,
) async {
  final consent = await store.read();
  if (consent == CrashReportingConsent.granted) await reporter.start();
  return consent;
}

/// Aceitar ou recusar o relatório de falhas, valendo na hora.
final class SetCrashReportingConsent {
  const SetCrashReportingConsent(this._store, this._reporter);

  final CrashReportingConsentStore _store;
  final CrashReporter _reporter;

  /// Aceitar grava a resposta e liga o relatório. Recusar desliga antes de
  /// gravar, para nada mais sair do aparelho mesmo se a gravação falhar.
  Future<void> call({required bool granted}) async {
    if (granted) {
      await _store.write(CrashReportingConsent.granted);
      await _reporter.start();
    } else {
      await _reporter.stop();
      await _store.write(CrashReportingConsent.denied);
    }
  }
}
