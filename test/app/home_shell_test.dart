import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:bipa/app/home_shell.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/design_system/components/scan_nav_bar.dart';
import 'package:bipa/core/design_system/components/shopping_list.dart';
import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/core/navigation/routes.dart';
import 'package:bipa/features/shopping_list/domain/shopping_trip.dart';
import 'package:bipa/features/shopping_list/presentation/shopping_list_providers.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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

Widget _app(
  _Tabs tabs, {
  bool reduceMotion = true,
  double textScale = 1,
  bool accessibleNavigation = false,
  ShoppingTripSummary? trip,
}) {
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
      // Uma tela que cobre o shell, como a câmera.
      GoRoute(
        path: '/cobre',
        builder: (_, _) => const Scaffold(body: Text('cobre')),
      ),
      GoRoute(
        path: Routes.cartMode,
        builder: (_, _) => const Scaffold(body: Text('carrinho')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      // Sem banco; fora de uma compra, sem a barra da compra.
      shoppingTripSummaryProvider.overrideWith((ref) => trip),
      activeTripMarketNameProvider.overrideWith((ref) => null),
    ],
    child: MaterialApp.router(
      theme: BipaTheme.light,
      locale: const Locale('pt'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: reduceMotion,
          textScaler: TextScaler.linear(textScale),
          accessibleNavigation: accessibleNavigation,
        ),
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

/// Os rótulos dos destinos, na ordem da barra.
const _labels = ['Início', 'Produtos', 'Mercados', 'Lista'];

/// A altura do celular nos testes de letra grande.
const _phoneHeight = 800.0;

/// A largura de um texto depende da fonte: sem a Figtree do app, o teste
/// mediria com a fonte de testes do Flutter, de glifos quadrados, e os
/// rótulos encolheriam muito mais que no aparelho.
Future<void> _loadAppFonts() async {
  final figtree = FontLoader('Figtree');
  for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    final bytes = File('assets/fonts/Figtree-$weight.ttf').readAsBytesSync();
    figtree.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await figtree.load();
}

/// Um celular de [width] dp.
void _usePhone(WidgetTester tester, double width) {
  tester.view
    ..physicalSize = Size(width, _phoneHeight)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// O parágrafo de cada rótulo, na barra (o balão fica no overlay, fora dela).
List<RenderParagraph> _labelParagraphs(WidgetTester tester) => [
  for (final label in _labels)
    tester.renderObject<RenderParagraph>(find.descendant(of: find.byType(ScanNavBar), matching: find.text(label))),
];

/// O botão de bipar na tela.
Rect _scanRect(WidgetTester tester) => tester.getRect(
  find.ancestor(of: find.byIcon(Icons.qr_code_scanner_rounded), matching: find.byType(SizedBox)).first,
);

/// A pílula de vidro na tela.
Rect _pillRect(WidgetTester tester) =>
    tester.getRect(find.descendant(of: find.byType(ScanNavBar), matching: find.byType(BackdropFilter)));

/// Uma compra em andamento: "3 de 7 itens".
const _trip = ShoppingTripSummary(done: 3, total: 7);

/// A escala de letra como porcentagem, para o nome do teste.
String _percent(double scale) => '${(scale * 100).round()}%';

void main() {
  late _Tabs tabs;
  setUpAll(_loadAppFonts);
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
    // Com movimento, o anel do botão de bipar respira sem parar e o
    // pumpAndSettle nunca assentaria: os quadros avançam no relógio.
    await tester.pumpWidget(_app(tabs, reduceMotion: false));
    await tester.pump(const Duration(seconds: 1));

    tabs.controllers[_paths.first]!.jumpTo(300);
    await tester.pump();
    expect(_scanSize(tester), 64);
    await tester.pump(const Duration(milliseconds: 150));
    expect(_scanSize(tester), allOf(lessThan(64), greaterThan(50)));
    await tester.pump(const Duration(seconds: 1));
    expect(_scanSize(tester), 56);
    semantics.dispose();
  });

  testWidgets('o anel respira no botão de bipar e volta ao ponto de partida', (tester) async {
    await tester.pumpWidget(_app(tabs, reduceMotion: false));
    await tester.pump();

    // `bipa-breathe`: 2,4 s; aos 50% o anel está em 1,22 e transparente.
    ({double scale, double opacity}) ring() {
      final scale = tester.widget<Transform>(
        find.ancestor(of: find.byKey(ScanNavBar.ringKey), matching: find.byType(Transform)).first,
      );
      final box = tester.widget<DecoratedBox>(find.byKey(ScanNavBar.ringKey));
      final color = (box.decoration as ShapeDecoration).color!;
      return (scale: scale.transform.getMaxScaleOnAxis(), opacity: color.a);
    }

    expect(ring().scale, closeTo(1, 0.001));
    expect(ring().opacity, closeTo(0.35, 0.01));
    await tester.pump(const Duration(milliseconds: 1200));
    expect(ring().scale, closeTo(1.22, 0.001));
    expect(ring().opacity, closeTo(0, 0.01));
    await tester.pump(const Duration(milliseconds: 1200));
    expect(ring().scale, closeTo(1, 0.001));
    expect(ring().opacity, closeTo(0.35, 0.01));
    // Passa dos limites do botão sem deixar de ser só desenho.
    expect(find.ancestor(of: find.byKey(ScanNavBar.ringKey), matching: find.byType(IgnorePointer)), findsWidgets);
  });

  testWidgets('com movimento reduzido, o anel fica parado e nem é desenhado', (tester) async {
    await tester.pumpWidget(_app(tabs));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(ScanNavBar.ringKey), findsNothing);
    // Nenhum ticker ativo: a barra não pede quadros.
    expect(tester.hasRunningAnimations, isFalse);
    await tester.pump(const Duration(seconds: 5));
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('ligar o movimento reduzido para o anel que já respirava', (tester) async {
    await tester.pumpWidget(_app(tabs, reduceMotion: false));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(ScanNavBar.ringKey), findsOneWidget);
    expect(tester.hasRunningAnimations, isTrue);

    await tester.pumpWidget(_app(tabs));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(ScanNavBar.ringKey), findsNothing);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('com a barra fora da tela, o anel não pede quadros', (tester) async {
    await tester.pumpWidget(_app(tabs, reduceMotion: false));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.hasRunningAnimations, isTrue);

    // Uma rota por cima (a câmera, por exemplo) desliga os tickers da de baixo.
    final router = GoRouter.of(tester.element(find.byType(HomeShell)));
    unawaited(router.push('/cobre'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.hasRunningAnimations, isFalse);
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

  // H8, quadro "NavLetraGrande": até 160%, a barra de sempre com os rótulos
  // até 130% e encolhidos até caber; acima, o bipar flutua acima da barra.
  group('letra grande', () {
    for (final width in [360.0, 411.0]) {
      for (final scale in [1.0, 1.3, 1.5, 1.7, 2.0]) {
        final floating = scale > 1.6;
        testWidgets('a ${_percent(scale)} em ${width.toInt()} dp, os rótulos cabem inteiros e o bipar fica '
            '${floating ? 'acima da barra' : 'no meio'}', (tester) async {
          final semantics = tester.ensureSemantics();
          _usePhone(tester, width);
          await tester.pumpWidget(_app(tabs, textScale: scale));
          await tester.pumpAndSettle();

          // Nenhum rótulo cortado, e os quatro no mesmo tamanho: nunca menor
          // que o normal, nem maior que a letra pedida (até 130% com o bipar
          // no meio).
          final paragraphs = _labelParagraphs(tester);
          for (final paragraph in paragraphs) {
            expect(paragraph.didExceedMaxLines, isFalse, reason: '"${paragraph.text.toPlainText()}" cortado');
          }
          final sizes = {for (final p in paragraphs) p.textScaler.scale(p.text.style!.fontSize!).toStringAsFixed(2)};
          expect(sizes, hasLength(1), reason: 'rótulos em tamanhos diferentes: $sizes');
          final size = double.parse(sizes.single);
          expect(size, greaterThanOrEqualTo(12));
          expect(size, lessThanOrEqualTo(12 * (floating ? scale : math.min(scale, 1.3)) + 0.01));

          final scan = _scanRect(tester);
          final pill = _pillRect(tester);
          expect(scan.size, const Size.square(64));
          if (floating) {
            // À direita, 16 px da borda, e inteiro acima da pílula, 12 px acima.
            expect(scan.right, closeTo(width - 16, 0.5));
            expect(scan.bottom, closeTo(pill.top - 12, 0.5));
            // Os quatro destinos dividem a largura: o meio da barra fica
            // entre o segundo e o terceiro.
            final second = tester.getCenter(
              find.descendant(of: find.byType(ScanNavBar), matching: find.text('Produtos')),
            );
            final third = tester.getCenter(
              find.descendant(of: find.byType(ScanNavBar), matching: find.text('Mercados')),
            );
            expect((second.dx + third.dx) / 2, closeTo(width / 2, 0.5));
            expect(pill.height, greaterThanOrEqualTo(68));
          } else {
            // No meio, 18 px acima da pílula de 68.
            expect(scan.center.dx, closeTo(width / 2, 0.5));
            expect(pill.top - scan.top, closeTo(18, 0.5));
            expect(pill.height, 68);
          }

          // O conteúdo reserva o espaço da barra e do bipar, flutuante ou não.
          final content = tester.element(find.byKey(ValueKey(_paths.first)));
          expect(
            MediaQuery.paddingOf(content).bottom,
            greaterThanOrEqualTo(_phoneHeight - math.min(scan.top, pill.top)),
          );

          // O leitor de tela ouve os mesmos destinos e o toque longo do bipar.
          for (final label in _labels) {
            expect(
              tester.getSemantics(find.bySemanticsLabel(label)),
              isSemantics(label: label, isButton: true, hasTapAction: true),
            );
          }
          expect(
            tester.getSemantics(find.bySemanticsLabel('Bipar')),
            isSemantics(label: 'Bipar', isButton: true, hasTapAction: true, hasLongPressAction: true),
          );
          semantics.dispose();
        });
      }
    }

    for (final scale in [1.3, 1.5, 1.7, 2.0]) {
      testWidgets('a ${_percent(scale)}, a barra não encolhe ao rolar', (tester) async {
        _usePhone(tester, 360);
        await tester.pumpWidget(_app(tabs, textScale: scale));
        await tester.pumpAndSettle();
        final pill = _pillRect(tester);

        await tester.drag(find.byKey(ValueKey(_paths.first)), const Offset(0, -300));
        await tester.pumpAndSettle();
        expect(tabs.controllers[_paths.first]!.offset, greaterThan(100));
        expect(_pillRect(tester), pill);
        expect(_scanRect(tester).size, const Size.square(64));
        for (final label in _labels) {
          final text = find.descendant(of: find.byType(ScanNavBar), matching: find.text(label));
          expect(tester.widget<Opacity>(find.ancestor(of: text, matching: find.byType(Opacity)).first).opacity, 1);
        }
      });
    }

    testWidgets('com o TalkBack, a barra não encolhe ao rolar', (tester) async {
      await tester.pumpWidget(_app(tabs, accessibleNavigation: true));
      await tester.pumpAndSettle();
      await _scrollTo(tester, tabs, 300);
      expect(_pillHeight(tester), 68);
      expect(_scanRect(tester).size, const Size.square(64));
    });

    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('a ${_percent(scale)}, segurar um destino mostra o rótulo grande num balão', (tester) async {
        _usePhone(tester, 360);
        await tester.pumpWidget(_app(tabs, textScale: scale));
        await tester.pumpAndSettle();
        final balloon = find.byKey(ScanNavBar.balloonKey);
        expect(balloon, findsNothing);
        final scan = _scanRect(tester);
        final pill = _pillRect(tester);

        final markets = find.descendant(of: find.byType(ScanNavBar), matching: find.text('Mercados'));
        final gesture = await tester.startGesture(tester.getCenter(markets));
        await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
        expect(balloon, findsOneWidget);
        expect(find.descendant(of: balloon, matching: find.text('Mercados')), findsOneWidget);
        // Acima da barra, sem cobrir o bipar.
        final rect = tester.getRect(balloon);
        expect(rect.bottom, lessThanOrEqualTo(pill.top));
        expect(rect.overlaps(scan), isFalse);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(360));

        // Soltar esconde o balão, sem trocar de aba.
        await gesture.up();
        await tester.pumpAndSettle();
        expect(balloon, findsNothing);
        expect(find.text('/inicio 0'), findsOneWidget);
      });
    }

    for (final scale in [1.0, 2.0]) {
      testWidgets('a ${_percent(scale)}, segurar o bipar abre o menu com o "×" no lugar do botão', (tester) async {
        _usePhone(tester, 360);
        await tester.pumpWidget(_app(tabs, textScale: scale));
        await tester.pumpAndSettle();
        final scan = _scanRect(tester);
        // Com a barra compacta, o "×" vai para onde o botão fica na normal,
        // que é como a barra volta ao abrir o menu.
        if (scale == 1.0) {
          await _scrollTo(tester, tabs, 300);
          expect(_scanRect(tester).size, const Size.square(56));
        }

        await tester.longPress(find.byIcon(Icons.qr_code_scanner_rounded));
        await tester.pumpAndSettle();
        expect(find.byKey(ScanNavBar.balloonKey), findsNothing);
        final cart = find.text('Modo carrinho');
        expect(cart, findsOneWidget);
        final close = find.byIcon(Icons.close_rounded);
        expect(tester.getCenter(close), offsetMoreOrLessEquals(scan.center));
        // As pílulas ficam acima do "×"; com o bipar à direita, alinhadas a ele.
        final pill = tester.getRect(find.ancestor(of: cart, matching: find.byType(Material)).first);
        expect(pill.bottom, lessThan(scan.top));
        if (scale > 1.6) expect(pill.right, closeTo(scan.right, 0.5));

        await tester.tap(close);
        await tester.pumpAndSettle();
        expect(cart, findsNothing);
      });
    }

    testWidgets('acima de 160%, o anel respira em volta do bipar flutuante e para com movimento reduzido', (
      tester,
    ) async {
      _usePhone(tester, 360);
      await tester.pumpWidget(_app(tabs, reduceMotion: false, textScale: 2));
      await tester.pump(const Duration(seconds: 1));
      final ring = find.byKey(ScanNavBar.ringKey);
      expect(ring, findsOneWidget);
      expect(tester.getCenter(ring), offsetMoreOrLessEquals(_scanRect(tester).center));

      await tester.pumpWidget(_app(tabs, textScale: 2));
      await tester.pump(const Duration(seconds: 1));
      expect(ring, findsNothing);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  // H12, quadro "NavLetraGrandeCompra", decisão A: acima de 160%, durante a
  // compra, o bipar flutuante sai e a barra da compra fica no lugar dele.
  group('letra grande durante a compra', () {
    final shoppingBar = find.byType(ShoppingBar);
    final scanButton = find.byIcon(Icons.qr_code_scanner_rounded);

    for (final scale in [1.7, 2.0]) {
      testWidgets('a ${_percent(scale)}, a barra da compra fica no lugar do bipar flutuante', (tester) async {
        final semantics = tester.ensureSemantics();
        _usePhone(tester, 360);
        await tester.pumpWidget(_app(tabs, textScale: scale, trip: _trip));
        await tester.pumpAndSettle();

        // Um amarelo só: sem o bipar, e a barra da compra logo acima da pílula.
        expect(scanButton, findsNothing);
        expect(shoppingBar, findsOneWidget);
        final bar = tester.getRect(shoppingBar);
        final pill = _pillRect(tester);
        expect(bar.bottom, lessThanOrEqualTo(pill.top));
        expect(pill.top - bar.bottom, lessThan(16));

        // O conteúdo reserva a barra da compra e a pílula, sem o vão do bipar.
        final content = tester.element(find.byKey(ValueKey(_paths.first)));
        final reserved = MediaQuery.paddingOf(content).bottom;
        expect(reserved, greaterThanOrEqualTo(_phoneHeight - bar.top));
        expect(reserved, lessThan(_phoneHeight - bar.top + 64));

        // O leitor de tela ouve o toque longo da barra e o que ele faz.
        final barNode = find.descendant(
          of: shoppingBar,
          matching: find.byWidgetPredicate(
            (widget) => widget is Semantics && widget.properties.hintOverrides?.onLongPressHint == 'Mais opções',
          ),
        );
        expect(barNode, findsOneWidget);
        expect(tester.getSemantics(barNode), isSemantics(isButton: true, hasTapAction: true, hasLongPressAction: true));

        // Segurar a barra abre o menu do bipar, com o "×" no fim dela e as
        // pílulas acima dela, alinhadas ao "×".
        await tester.longPress(shoppingBar);
        await tester.pumpAndSettle();
        final cart = find.text('Modo carrinho');
        expect(cart, findsOneWidget);
        final close = tester.getRect(find.byIcon(Icons.close_rounded));
        expect(close.center.dy, closeTo(bar.center.dy, 0.5));
        expect(close.right, lessThanOrEqualTo(bar.right));
        expect(close.right, greaterThan(bar.right - 16));
        final menuPill = tester.getRect(find.ancestor(of: cart, matching: find.byType(Material)).first);
        expect(menuPill.bottom, lessThan(bar.top));

        // "Modo carrinho" volta à compra.
        await tester.tap(cart);
        await tester.pumpAndSettle();
        expect(find.text('carrinho'), findsOneWidget);
        semantics.dispose();
      });
    }

    testWidgets('a 200%, tocar na barra da compra continua a compra', (tester) async {
      _usePhone(tester, 360);
      await tester.pumpWidget(_app(tabs, textScale: 2, trip: _trip));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(find.text('carrinho'), findsOneWidget);
    });

    testWidgets('a 200%, na Lista, sem a barra da compra, o bipar flutua como sempre', (tester) async {
      final semantics = tester.ensureSemantics();
      _usePhone(tester, 360);
      await tester.pumpWidget(_app(tabs, textScale: 2, trip: _trip));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Lista'));
      await tester.pumpAndSettle();
      expect(shoppingBar, findsNothing);
      expect(_scanRect(tester).size, const Size.square(64));
      semantics.dispose();
    });

    for (final scale in [1.0, 1.5]) {
      testWidgets('a ${_percent(scale)}, o bipar fica no meio e a barra da compra não tem toque longo', (tester) async {
        final semantics = tester.ensureSemantics();
        _usePhone(tester, 360);
        await tester.pumpWidget(_app(tabs, textScale: scale, trip: _trip));
        await tester.pumpAndSettle();
        expect(shoppingBar, findsOneWidget);
        expect(_scanRect(tester).center.dx, closeTo(180, 0.5));
        expect(
          tester.getSemantics(find.descendant(of: shoppingBar, matching: find.byType(Semantics)).first),
          isSemantics(isButton: true, hasTapAction: true, hasLongPressAction: false),
        );
        semantics.dispose();
      });
    }
  });
}
