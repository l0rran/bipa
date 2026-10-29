import 'package:bipa/app/daily_backup.dart';
import 'package:bipa/app/router.dart';
import 'package:bipa/core/accessibility/recommended_timeouts.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/features/shopping_list/presentation/live_shopping_notification.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BipaApp extends ConsumerWidget {
  const BipaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // O "Tempo para agir" do Android fica acima do MaterialApp, para o
    // ScaffoldMessenger do app também enxergar (o tempo do bipa-toast).
    return RecommendedTimeoutsLoader(
      child: MaterialApp.router(
        title: 'Bipa',
        debugShowCheckedModeBanner: false,
        theme: BipaTheme.light,
        darkTheme: BipaTheme.dark,
        // O app nasce no tema claro; o escuro existe nos tokens para depois.
        themeMode: ThemeMode.light,
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
        routerConfig: ref.watch(routerProvider),
        // A notificação ao vivo da compra e o backup diário acompanham o app
        // inteiro, acima das rotas.
        builder: (context, child) =>
            LiveShoppingNotification(child: DailyBackup(child: child ?? const SizedBox.shrink())),
      ),
    );
  }
}
