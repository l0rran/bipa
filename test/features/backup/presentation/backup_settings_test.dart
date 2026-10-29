import 'package:bipa/core/crash_reporting/crash_reporting.dart';
import 'package:bipa/core/crash_reporting/crash_reporting_providers.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/di/core_providers.dart';
import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/features/backup/presentation/backup_files.dart';
import 'package:bipa/features/backup/presentation/backup_providers.dart';
import 'package:bipa/features/settings/presentation/settings_page.dart';
import 'package:bipa/features/settings/presentation/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/backup_fakes.dart';
import '../../../helpers/crash_reporting_fakes.dart';

final _now = DateTime(2026, 10, 29, 10);

/// Os Ajustes com o backup e o seletor falsos.
Future<void> pumpSettings(WidgetTester tester, {required FakeBackupController backup, BackupFiles? files}) async {
  tester.view
    ..physicalSize = const Size(411, 1600)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        backupProvider.overrideWith(() => backup),
        backupFilesProvider.overrideWithValue(files ?? FakeBackupFiles()),
        clockProvider.overrideWithValue(() => _now),
        crashReportingConsentStoreProvider.overrideWithValue(MemoryConsentStore()),
        crashReporterProvider.overrideWithValue(FakeCrashReporter()),
        initialCrashReportingConsentProvider.overrideWithValue(CrashReportingConsent.unasked),
        appVersionProvider.overrideWith((ref) async => '0.1.0'),
      ],
      child: MaterialApp(
        theme: BipaTheme.light,
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
        home: const SettingsPage(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

/// Deixa o aviso sair, para o teste não terminar com o relógio dele rodando.
Future<void> finishToasts(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 11));
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('o grupo "Backup" vem primeiro, com o último backup como número e as ações', (tester) async {
    await pumpSettings(
      tester,
      backup: FakeBackupController(
        initial: BackupState(lastBackup: fakeBackupInfo(createdAt: DateTime(2026, 10, 29, 8, 40))),
      ),
    );

    expect(find.text('BACKUP'), findsOneWidget);
    expect(tester.getTopLeft(find.text('BACKUP')).dy, lessThan(tester.getTopLeft(find.text('PRIVACIDADE')).dy));
    expect(find.text('Último backup'), findsOneWidget);
    expect(find.text('hoje'), findsOneWidget);
    expect(find.text('08:40'), findsOneWidget);
    expect(find.textContaining('Automático, uma vez por dia'), findsOneWidget);
    expect(find.text('Fazer backup agora'), findsOneWidget);
    expect(find.text('Salvar uma cópia…'), findsOneWidget);
    expect(find.text('Para guardar fora do celular'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp(r'^Último backup: hoje, 08:40\. Automático')),
      findsOneWidget,
      reason: 'o leitor de tela ouve o dia e a hora juntos',
    );
  });

  testWidgets('sem backup, "nenhum ainda"', (tester) async {
    await pumpSettings(tester, backup: FakeBackupController());
    expect(find.text('nenhum ainda'), findsOneWidget);
  });

  testWidgets('de ontem, "ontem"', (tester) async {
    await pumpSettings(
      tester,
      backup: FakeBackupController(
        initial: BackupState(lastBackup: fakeBackupInfo(createdAt: DateTime(2026, 10, 28, 8, 40))),
      ),
    );
    expect(find.text('ontem'), findsOneWidget);
  });

  testWidgets('mais velho, a data', (tester) async {
    await pumpSettings(
      tester,
      backup: FakeBackupController(
        initial: BackupState(lastBackup: fakeBackupInfo(createdAt: DateTime(2026, 10, 12, 21))),
      ),
    );
    expect(find.text('12/10'), findsOneWidget);
    expect(find.text('21:00'), findsOneWidget);
  });

  testWidgets('acima de 25 MB, a linha diz o tamanho e sugere "Salvar uma cópia…"', (tester) async {
    await pumpSettings(
      tester,
      backup: FakeBackupController(
        initial: BackupState(
          lastBackup: fakeBackupInfo(createdAt: DateTime(2026, 10, 29, 8, 40), size: 30 * 1024 * 1024 + 1),
        ),
      ),
    );

    expect(find.textContaining('Com 31 MB, passou dos 25 MB'), findsOneWidget);
    expect(find.textContaining('Automático, uma vez por dia'), findsNothing);
  });

  testWidgets('"Fazer backup agora" grava e o valor passa a "agora", sem aviso', (tester) async {
    final backup = FakeBackupController(
      initial: BackupState(lastBackup: fakeBackupInfo(createdAt: DateTime(2026, 10, 28, 8, 40))),
      onCreate: () async => fakeBackupInfo(createdAt: _now, id: 'novo'),
    );
    await pumpSettings(tester, backup: backup);

    await tester.tap(find.text('Fazer backup agora'));
    await tester.pump();
    await tester.pump();

    expect(backup.calls, ['create']);
    expect(find.text('agora'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('"Fazer backup agora" que falha avisa', (tester) async {
    final backup = FakeBackupController(onCreate: () async => throw const FileSystemExceptionForTest());
    await pumpSettings(tester, backup: backup);

    await tester.tap(find.text('Fazer backup agora'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Não deu para fazer o backup. Tente de novo.'), findsOneWidget);
    await finishToasts(tester);
  });

  testWidgets('"Salvar uma cópia…" grava e abre o "Salvar como" com o nome do dia', (tester) async {
    final backup = FakeBackupController();
    final files = FakeBackupFiles();
    await pumpSettings(tester, backup: backup, files: files);

    await tester.tap(find.text('Salvar uma cópia…'));
    await tester.pump();
    await tester.pump();

    expect(backup.calls, ['saveCopy']);
    expect(files.savedNames, ['bipa-2026-10-29.bipa']);
    expect(find.text('Cópia salva'), findsOneWidget);
    await finishToasts(tester);
  });

  testWidgets('voltar do "Salvar como" sem escolher não avisa nada', (tester) async {
    final files = FakeBackupFiles(saveAnswer: false);
    await pumpSettings(tester, backup: FakeBackupController(), files: files);

    await tester.tap(find.text('Salvar uma cópia…'));
    await tester.pump();
    await tester.pump();

    expect(files.savedNames, hasLength(1));
    expect(find.byType(SnackBar), findsNothing);
  });
}

/// Uma falha de disco ao gravar o backup.
final class FileSystemExceptionForTest implements Exception {
  const FileSystemExceptionForTest();
}
