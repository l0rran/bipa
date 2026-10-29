import 'dart:ui' as ui;

import 'package:bipa/app/home_shell.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/design_system/components/scan_nav_bar.dart';
import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/features/shopping_list/presentation/shopping_list_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// As quatro abas do shell, cada uma com uma lista longa e o seu controle de
/// rolagem.
final _paths = ['/inicio', '/produtos', '/mercados', '/lista'];

class _Tabs {
  final controllers = {for (final path in _paths) path: ScrollController()};

  /// Quantos itens a lista do Início tem: diminuir deixa de rolar.
  final homeCount = ValueNotifier(60);

  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    homeCount.dispose();
  }
}

Widget _app(_Tabs tabs, {bool reduceMotion = false}) {
  final router = GoRouter(
    initialLocation: _paths.first,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => HomeShell(navigationShell: shell),
        branches: [
          for (final path in _paths)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: path,
                  builder: (_, _) => Scaffold(
                    body: ValueListenableBuilder(
                      valueListenable: tabs.homeCount,
                      builder: (_, count, _) => ListView.builder(
                        key: ValueKey(path),
                        controller: tabs.controllers[path],
                        itemCount: path == _paths.first ? count : 60,
                        itemBuilder: (_, i) => SizedBox(height: 56, child: Text('$path $i')),
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      // Fora de uma compra: sem a barra da compra e sem banco.
      shoppingTripSummaryProvider.overrideWith((ref) => null),
      activeTripMarketNameProvider.overrideWith((ref) => null),
    ],
    child: MaterialApp.router(
      theme: BipaTheme.light,
      locale: const Locale('pt'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: child!,
      ),
    ),
  );
}

bool _compact(WidgetTester tester) => tester.widget<ScanNavBar>(find.byType(ScanNavBar)).compact;

/// A altura da pílula de vidro: 68 na barra normal, 52 na compacta.
double _pillHeight(WidgetTester tester) => tester.getSize(find.byType(BackdropFilter)).height;

/// Quanto o botão de bipar passa da borda de cima da pílula: 18 na barra
/// normal (64 px, `margin-top: -40px` no CSS), 16 na compacta (56 px).
double _scanLift(WidgetTester tester) =>
    tester.getTopLeft(find.byType(BackdropFilter)).dy - tester.getTopLeft(find.bySemanticsLabel('Bipar')).dy;

/// O lado do botão de bipar: 64 na barra normal, 56 na compacta.
double _scanSize(WidgetTester tester) => tester.getSize(find.bySemanticsLabel('Bipar')).width;

Future<void> _scrollTo(WidgetTester tester, _Tabs tabs, double offset, {String? path}) async {
  tabs.controllers[path ?? _paths.first]!.jumpTo(offset);
  await tester.pumpAndSettle();
}

void main() {
  late _Tabs tabs;
  setUp(() => tabs = _Tabs());
  tearDown(() => tabs.dispose());

  testWidgets('rolar para baixo encolhe a barra e rolar para cima a traz de volta', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(tabs));
    await tester.pumpAndSettle();
    expect(_compact(tester), isFalse);
    expect(_scanSize(tester), 64);

    // Com o dedo, como a pessoa rola.
    await tester.drag(find.byKey(ValueKey(_paths.first)), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(_compact(tester), isTrue);
    expect(_scanSize(tester), 56);

    await tester.drag(find.byKey(ValueKey(_paths.first)), const Offset(0, 120));
    await tester.pumpAndSettle();
    expect(tabs.controllers[_paths.first]!.offset, greaterThan(0));
    expect(_compact(tester), isFalse);
    expect(_scanSize(tester), 64);
    semantics.dispose();
  });

  testWidgets('um tremor menor que a histerese não muda a barra', (tester) async {
    await tester.pumpWidget(_app(tabs));
    await tester.pumpAndSettle();

    // Perto do topo, a barra não encolhe.
    await _scrollTo(tester, tabs, 20);
    expect(_compact(tester), isFalse);

    await _scrollTo(tester, tabs, 300);
    expect(_compact(tester), isTrue);

    await _scrollTo(tester, tabs, 295);
    expect(_compact(tester), isTrue);

    await _scrollTo(tester, tabs, 285);
    expect(_compact(tester), isFalse);

    await _scrollTo(tester, tabs, 290);
    expect(_compact(tester), isFalse);
  });

  testWidgets('chegar ao topo e o conteúdo deixar de rolar trazem a barra de volta', (tester) async {
    await tester.pumpWidget(_app(tabs));
    await tester.pumpAndSettle();

    await _scrollTo(tester, tabs, 300);
    expect(_compact(tester), isTrue);
    await _scrollTo(tester, tabs, 0);
    expect(_compact(tester), isFalse);

    await _scrollTo(tester, tabs, 300);
    expect(_compact(tester), isTrue);
    tabs.homeCount.value = 3;
    await tester.pumpAndSettle();
    expect(_compact(tester), isFalse);
  });

  testWidgets('trocar de aba traz a barra de volta', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(tabs));
    await tester.pumpAndSettle();

    await _scrollTo(tester, tabs, 300);
    expect(_compact(tester), isTrue);

    await tester.tap(find.bySemanticsLabel('Produtos'));
    await tester.pumpAndSettle();
    expect(find.text('/produtos 0'), findsOneWidget);
    expect(_compact(tester), isFalse);
    expect(_scanSize(tester), 64);

    // Encolhe pela lista da aba nova, e voltar ao Início, que continua
    // rolado, também traz a barra de volta.
    await _scrollTo(tester, tabs, 300, path: '/produtos');
    expect(_compact(tester), isTrue);
    await tester.tap(find.bySemanticsLabel('Início'));
    await tester.pumpAndSettle();
    expect(tabs.controllers[_paths.first]!.offset, 300);
    expect(_compact(tester), isFalse);
    semantics.dispose();
  });

  testWidgets('a rolagem de uma aba escondida não mexe na barra', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(tabs));
    await tester.pumpAndSettle();
    // Abre Produtos uma vez, para a lista dela existir, e volta.
    await tester.tap(find.bySemanticsLabel('Produtos'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Início'));
    await tester.pumpAndSettle();

    await _scrollTo(tester, tabs, 300, path: '/produtos');
    expect(_compact(tester), isFalse);
    semantics.dispose();
  });

  testWidgets('compacta, os rótulos somem da tela mas não do leitor de tela', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(tabs));
    await tester.pumpAndSettle();
    await _scrollTo(tester, tabs, 300);
    expect(_compact(tester), isTrue);

    for (final label in ['Início', 'Produtos', 'Mercados', 'Lista']) {
      expect(
        tester.getSemantics(find.bySemanticsLabel(label)),
        isSemantics(label: label, isButton: true, hasTapAction: true),
      );
      // O texto continua na árvore, mas transparente e sem altura.
      final opacity = tester.widget<Opacity>(find.ancestor(of: find.text(label), matching: find.byType(Opacity)).first);
      expect(opacity.opacity, 0);
    }
    expect(
      tester.getSemantics(find.bySemanticsLabel('Bipar')),
      isSemantics(label: 'Bipar', isButton: true, hasTapAction: true, hasLongPressAction: true),
    );
    semantics.dispose();
  });

  testWidgets('com movimento reduzido, a barra troca de tamanho sem animar', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(tabs, reduceMotion: true));
    await tester.pumpAndSettle();

    tabs.controllers[_paths.first]!.jumpTo(300);
    await tester.pump();
    expect(_scanSize(tester), 56);

    tabs.controllers[_paths.first]!.jumpTo(0);
    await tester.pump();
    expect(_scanSize(tester), 64);
    semantics.dispose();
  });

  testWidgets('com movimento, a barra anima até o tamanho compacto', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(tabs));
    await tester.pumpAndSettle();

    tabs.controllers[_paths.first]!.jumpTo(300);
    await tester.pump();
    expect(_scanSize(tester), 64);
    await tester.pump(const Duration(milliseconds: 150));
    expect(_scanSize(tester), allOf(lessThan(64), greaterThan(50)));
    await tester.pumpAndSettle();
    expect(_scanSize(tester), 56);
    semantics.dispose();
  });

  testWidgets('o conteúdo reserva o espaço da barra normal nos dois tamanhos', (tester) async {
    await tester.pumpWidget(_app(tabs));
    await tester.pumpAndSettle();
    final shellContext = tester.element(find.byKey(ValueKey(_paths.first)));
    final normal = MediaQuery.paddingOf(shellContext).bottom;
    // 68 da pílula, 18 do botão que sobe e 12 de margem.
    expect(normal, greaterThanOrEqualTo(68 + 18 + 12));

    await _scrollTo(tester, tabs, 300);
    expect(_compact(tester), isTrue);
    expect(MediaQuery.paddingOf(shellContext).bottom, normal);
  });

  testWidgets('as medidas da barra seguem o design system', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(tabs, reduceMotion: true));
    await tester.pumpAndSettle();
    expect(_pillHeight(tester), 68);
    expect(_scanSize(tester), 64);
    expect(_scanLift(tester), 18);

    await _scrollTo(tester, tabs, 300);
    expect(_compact(tester), isTrue);
    expect(_pillHeight(tester), 52);
    expect(_scanSize(tester), 56);
    expect(_scanLift(tester), 16);
    semantics.dispose();
  });

  testWidgets('o vidro da barra desfoca com raio 18', (tester) async {
    await tester.pumpWidget(_app(tabs, reduceMotion: true));
    await tester.pumpAndSettle();
    final glass = tester.widget<BackdropFilter>(find.byType(BackdropFilter));
    expect(glass.filter, ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18));
  });
}
