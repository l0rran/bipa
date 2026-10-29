import 'package:bipa/core/crash_reporting/crash_reporting.dart';
import 'package:bipa/core/crash_reporting/crash_reporting_providers.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/features/backup/presentation/backup_providers.dart';
import 'package:bipa/features/products/presentation/products_providers.dart';
import 'package:bipa/features/settings/presentation/settings_page.dart';
import 'package:bipa/features/settings/presentation/settings_providers.dart';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/backup_fakes.dart';
import '../../../helpers/crash_reporting_fakes.dart';

Future<({MemoryConsentStore store, FakeCrashReporter reporter})> _pump(
  WidgetTester tester, {
  CrashReportingConsent consent = CrashReportingConsent.unasked,
  bool available = true,
  String? attribution,
}) async {
  // Um celular alto, para a tela inteira ficar à vista.
  tester.view
    ..physicalSize = const Size(411, 2000)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final store = MemoryConsentStore(consent);
  final reporter = FakeCrashReporter(isAvailable: available);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        crashReportingConsentStoreProvider.overrideWithValue(store),
        crashReporterProvider.overrideWithValue(reporter),
        initialCrashReportingConsentProvider.overrideWithValue(consent),
        appVersionProvider.overrideWith((ref) async => '0.1.0'),
        backupProvider.overrideWith(FakeBackupController.new),
        catalogAttributionProvider.overrideWith((ref) async => attribution),
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
  await tester.pumpAndSettle();
  return (store: store, reporter: reporter);
}

Finder get _switch => find.byType(Switch);

void main() {
  testWidgets('mostra o interruptor desligado, o que vai, o que nunca vai e a versão', (tester) async {
    await _pump(tester);

    expect(find.text('Ajustes'), findsOneWidget);
    expect(tester.widget<Switch>(_switch).value, isFalse);
    expect(find.text('Relatório de falhas'), findsOneWidget);
    expect(find.text('O que vai'), findsOneWidget);
    expect(find.textContaining('Versão do app, do Android e do Flutter'), findsOneWidget);
    expect(find.textContaining('Os últimos passos do app'), findsOneWidget);
    expect(find.text('O que nunca vai'), findsOneWidget);
    expect(find.text('Produtos, preços, estoque e lista'), findsOneWidget);
    expect(find.text('0.1.0'), findsOneWidget);
  });

  testWidgets('"Sobre o Bipa" traz a atribuição do catálogo quando ele existe', (tester) async {
    const text = 'Contém informações do Open Food Facts, disponíveis sob a ODbL';
    await _pump(tester, attribution: text);
    expect(find.text(text), findsOneWidget);
  });

  testWidgets('sem catálogo, "Sobre o Bipa" fica só com a versão', (tester) async {
    await _pump(tester);
    expect(find.textContaining('Open Food Facts'), findsNothing);
  });

  testWidgets('o interruptor reflete o consentimento já dado', (tester) async {
    await _pump(tester, consent: CrashReportingConsent.granted);
    expect(tester.widget<Switch>(_switch).value, isTrue);
  });

  testWidgets('ligar aceita e inicia o relatório; desligar recusa e o fecha', (tester) async {
    final (:store, :reporter) = await _pump(tester);

    await tester.tap(_switch);
    await tester.pumpAndSettle();
    expect(store.value, CrashReportingConsent.granted);
    expect(reporter.calls, ['start']);
    expect(tester.widget<Switch>(_switch).value, isTrue);

    await tester.tap(_switch);
    await tester.pumpAndSettle();
    expect(store.value, CrashReportingConsent.denied);
    expect(reporter.calls, ['start', 'stop']);
    expect(tester.widget<Switch>(_switch).value, isFalse);
  });

  testWidgets('tocar no texto da linha também liga', (tester) async {
    final (:store, reporter: _) = await _pump(tester);

    await tester.tap(find.text('Relatório de falhas'));
    await tester.pumpAndSettle();
    expect(store.value, CrashReportingConsent.granted);
  });

  testWidgets('o leitor de tela lê o nome, a explicação e o estado do interruptor', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester);

    final node = tester.getSemantics(find.byType(SwitchListTile));
    expect(node.label, contains('Relatório de falhas'));
    expect(node.label, contains('manda o erro para ser corrigido'));
    expect(node.getSemanticsData().flagsCollection.isToggled, Tristate.isFalse);
    handle.dispose();
  });

  testWidgets('sem DSN a seção de privacidade some e fica só a versão', (tester) async {
    await _pump(tester, available: false);

    expect(_switch, findsNothing);
    expect(find.text('PRIVACIDADE'), findsNothing);
    expect(find.text('Relatório de falhas'), findsNothing);
    expect(find.text('SOBRE O BIPA'), findsOneWidget);
    expect(find.text('0.1.0'), findsOneWidget);
  });

  testWidgets('o botão de voltar tem rótulo', (tester) async {
    await _pump(tester);
    expect(find.byTooltip('Voltar'), findsOneWidget);
  });
}
