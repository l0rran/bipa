import 'package:bipa/app/router.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BipaApp extends ConsumerWidget {
  const BipaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Bipa',
      debugShowCheckedModeBanner: false,
      theme: BipaTheme.light,
      darkTheme: BipaTheme.dark,
      // O app nasce no tema claro; o escuro existe nos tokens para depois.
      themeMode: ThemeMode.light,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
