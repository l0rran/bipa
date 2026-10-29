import 'package:bipa/core/crash_reporting/crash_reporting.dart';
import 'package:bipa/core/crash_reporting/crash_reporting_providers.dart';
import 'package:bipa/core/database/app_database.dart';
import 'package:bipa/core/database/database_provider.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/di/core_providers.dart';
import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/features/shopping_list/presentation/shopping_list_providers.dart';
import 'package:bipa/features/stock/presentation/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/crash_reporting_fakes.dart';
import '../../../helpers/fakes.dart';
import '../../../helpers/test_database.dart';

final _now = DateTime(2026, 10, 28, 9);

const _question = 'Se o Bipa travar, mandar um relatório?';

/// Quando a compra do teste está: sem compra, em andamento, terminada ou
/// cancelada.
enum _Trip { none, active, finished, cancelled }

/// Monta o Início como o app monta, com o banco em memória e o relatório de
/// falhas de mentira.
Future<({MemoryConsentStore store, FakeCrashReporter reporter, ProviderContainer container})> _pump(
  WidgetTester tester, {
  _Trip trip = _Trip.finished,
  CrashReportingConsent consent = CrashReportingConsent.unasked,
  bool available = true,
}) async {
  // Um celular alto, para o cartão e os botões ficarem à vista.
  tester.view
    ..physicalSize = const Size(411, 2000)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final AppDatabase db = createTestDatabase();
  final store = MemoryConsentStore(consent);
  final reporter = FakeCrashReporter(isAvailable: available);
  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      clockProvider.overrideWithValue(() => _now),
      idGeneratorProvider.overrideWithValue(SequentialIdGenerator()),
      crashReportingConsentStoreProvider.overrideWithValue(store),
      crashReporterProvider.overrideWithValue(reporter),
      initialCrashReportingConsentProvider.overrideWithValue(consent),
    ],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    container.dispose();
    await tester.runAsync(db.close);
  });

  await tester.runAsync(() async {
    final trips = container.read(shoppingTripRepositoryProvider);
    if (trip == _Trip.none) return;
    final started = await trips.start();
    switch (trip) {
      case _Trip.finished:
        await trips.finish(started.id);
      case _Trip.cancelled:
        await trips.cancel(started.id);
      case _Trip.none || _Trip.active:
        break;
    }
  });

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: BipaTheme.light,
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
        home: const Scaffold(body: HomePage()),
      ),
    ),
  );
  await _settle(tester);
  return (store: store, reporter: reporter, container: container);
}

/// Deixa o banco responder (ele roda fora do relógio falso do teste).
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  group('quando o cartão aparece', () {
    testWidgets('depois da primeira compra terminada, em build com DSN e sem resposta', (tester) async {
      await _pump(tester);

      expect(find.text(_question), findsOneWidget);
      expect(find.text('Mandar'), findsOneWidget);
      expect(find.text('Não mandar'), findsOneWidget);
      expect(find.byTooltip('Fechar sem mandar'), findsOneWidget);
    });

    testWidgets('não aparece antes de qualquer compra', (tester) async {
      await _pump(tester, trip: _Trip.none);
      expect(find.text(_question), findsNothing);
    });

    testWidgets('não aparece com a compra ainda em andamento', (tester) async {
      await _pump(tester, trip: _Trip.active);
      expect(find.text(_question), findsNothing);
    });

    testWidgets('não aparece depois de uma compra cancelada', (tester) async {
      await _pump(tester, trip: _Trip.cancelled);
      expect(find.text(_question), findsNothing);
    });

    testWidgets('não aparece em build sem DSN', (tester) async {
      await _pump(tester, available: false);
      expect(find.text(_question), findsNothing);
    });

    testWidgets('não aparece para quem já aceitou', (tester) async {
      await _pump(tester, consent: CrashReportingConsent.granted);
      expect(find.text(_question), findsNothing);
    });

    testWidgets('não aparece para quem já recusou', (tester) async {
      await _pump(tester, consent: CrashReportingConsent.denied);
      expect(find.text(_question), findsNothing);
    });

    testWidgets('aparece quando a primeira compra termina com o Início aberto', (tester) async {
      final (:store, :reporter, :container) = await _pump(tester, trip: _Trip.active);
      expect(find.text(_question), findsNothing);

      await tester.runAsync(() async {
        final trips = container.read(shoppingTripRepositoryProvider);
        await trips.finish((await trips.findActive())!.id);
      });
      await _settle(tester);

      expect(find.text(_question), findsOneWidget);
      expect(store.value, CrashReportingConsent.unasked);
      expect(reporter.calls, isEmpty);
    });
  });

  group('responder', () {
    testWidgets('"Mandar" aceita, liga o relatório e o cartão some', (tester) async {
      final (:store, :reporter, container: _) = await _pump(tester);

      await tester.tap(find.text('Mandar'));
      await _settle(tester);

      expect(store.value, CrashReportingConsent.granted);
      expect(reporter.calls, ['start']);
      expect(find.text(_question), findsNothing);
    });

    testWidgets('"Não mandar" recusa, não liga nada e o cartão some', (tester) async {
      final (:store, :reporter, container: _) = await _pump(tester);

      await tester.tap(find.text('Não mandar'));
      await _settle(tester);

      expect(store.value, CrashReportingConsent.denied);
      expect(reporter.calls, ['stop']);
      expect(find.text(_question), findsNothing);
    });

    testWidgets('fechar com o × conta como "não" e o cartão some', (tester) async {
      final (:store, :reporter, container: _) = await _pump(tester);

      await tester.tap(find.byTooltip('Fechar sem mandar'));
      await _settle(tester);

      expect(store.value, CrashReportingConsent.denied);
      expect(reporter.calls, ['stop']);
      expect(find.text(_question), findsNothing);

      expect(find.text(_question), findsNothing);
    });

    testWidgets('os dois botões têm o mesmo tamanho', (tester) async {
      await _pump(tester);

      final send = tester.getSize(find.widgetWithText(OutlinedButton, 'Mandar'));
      final decline = tester.getSize(find.widgetWithText(OutlinedButton, 'Não mandar'));
      expect(send, decline);
    });
  });
}
