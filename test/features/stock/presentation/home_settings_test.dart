import 'package:bipa/core/crash_reporting/crash_reporting_providers.dart';
import 'package:bipa/core/database/app_database.dart';
import 'package:bipa/core/database/database_provider.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/di/core_providers.dart';
import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/core/navigation/routes.dart';
import 'package:bipa/features/settings/presentation/settings_page.dart';
import 'package:bipa/features/settings/presentation/settings_providers.dart';
import 'package:bipa/features/stock/presentation/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../helpers/crash_reporting_fakes.dart';
import '../../../helpers/fakes.dart';
import '../../../helpers/test_database.dart';

final _now = DateTime(2026, 10, 28, 9);

void main() {
  testWidgets('a engrenagem ao lado de "Sua casa" abre os Ajustes', (tester) async {
    final AppDatabase db = createTestDatabase();
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => _now),
        idGeneratorProvider.overrideWithValue(SequentialIdGenerator()),
        crashReporterProvider.overrideWithValue(FakeCrashReporter()),
        appVersionProvider.overrideWith((ref) async => '0.1.0'),
      ],
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      container.dispose();
      await tester.runAsync(db.close);
    });

    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const HomePage()),
        GoRoute(path: Routes.settings, builder: (_, _) => const SettingsPage()),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          theme: BipaTheme.light,
          locale: const Locale('pt', 'BR'),
          supportedLocales: const [Locale('pt', 'BR')],
          localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(seconds: 1));

    expect(find.byTooltip('Ajustes'), findsOneWidget);
    await tester.tap(find.byTooltip('Ajustes'));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.text('Relatório de falhas'), findsOneWidget);
  });
}
