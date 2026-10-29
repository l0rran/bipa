import 'package:bipa/app/app.dart';
import 'package:bipa/core/crash_reporting/crash_reporting.dart';
import 'package:bipa/core/crash_reporting/crash_reporting_providers.dart';
import 'package:bipa/core/crash_reporting/file_crash_reporting_consent_store.dart';
import 'package:bipa/core/crash_reporting/sentry_crash_reporter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _registerFontLicenses();

  // O relatório de falhas liga antes do app, para pegar falhas da abertura,
  // e só se houver DSN e a pessoa tiver aceitado (ADR 0025).
  final consentStore = FileCrashReportingConsentStore(getApplicationSupportDirectory);
  final crashReporter = SentryCrashReporter.fromEnvironment();
  final consent = await startCrashReportingIfGranted(consentStore, crashReporter);

  runApp(
    ProviderScope(
      overrides: [
        crashReportingConsentStoreProvider.overrideWithValue(consentStore),
        crashReporterProvider.overrideWithValue(crashReporter),
        initialCrashReportingConsentProvider.overrideWithValue(consent),
      ],
      child: const BipaApp(),
    ),
  );
}

/// As fontes embutidas usam a SIL Open Font License, que pede que a licença
/// acompanhe o app. Ela aparece na tela de licenças do Flutter.
void _registerFontLicenses() {
  const fonts = {'Manrope': 'OFL-Manrope', 'Figtree': 'OFL-Figtree', 'JetBrains Mono': 'OFL-JetBrainsMono'};
  LicenseRegistry.addLicense(() async* {
    for (final MapEntry(key: name, value: file) in fonts.entries) {
      final text = await rootBundle.loadString('assets/fonts/$file.txt');
      yield LicenseEntryWithLineBreaks([name], text);
    }
  });
}
