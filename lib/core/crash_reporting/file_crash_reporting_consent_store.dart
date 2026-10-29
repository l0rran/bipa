import 'dart:io';

import 'package:bipa/core/crash_reporting/crash_reporting.dart';

/// Guarda a resposta num arquivo pequeno na pasta de suporte do app. É uma
/// preferência do aparelho, não um dado do domínio: fica fora do banco
/// (ADR 0025).
final class FileCrashReportingConsentStore implements CrashReportingConsentStore {
  FileCrashReportingConsentStore(this._directory);

  /// A pasta onde o arquivo fica; no app, `getApplicationSupportDirectory`.
  final Future<Directory> Function() _directory;

  static const fileName = 'crash_reporting_consent';

  Future<File> get _file async => File('${(await _directory()).path}${Platform.pathSeparator}$fileName');

  @override
  Future<CrashReportingConsent> read() async {
    try {
      final file = await _file;
      if (!await file.exists()) return CrashReportingConsent.unasked;
      final value = (await file.readAsString()).trim();
      return CrashReportingConsent.values.where((c) => c.name == value).firstOrNull ?? CrashReportingConsent.unasked;
    } on FileSystemException {
      // Sem conseguir ler, vale o padrão: não perguntado, nada é enviado.
      return CrashReportingConsent.unasked;
    }
  }

  @override
  Future<void> write(CrashReportingConsent consent) async {
    final file = await _file;
    await file.parent.create(recursive: true);
    await file.writeAsString(consent.name, flush: true);
  }
}
