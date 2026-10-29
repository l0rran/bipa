import 'package:bipa/core/accessibility/recommended_timeouts.dart';
import 'package:bipa/core/design_system/bipa_metrics.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/design_system/components/bipa_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Uma tela com um botão que mostra o aviso. [screenReader] liga o
/// `accessibleNavigation`, como o TalkBack; [reduceMotion], o
/// `disableAnimations`, como o "Remover animações" do Android; [asked], o
/// "Tempo para agir" do Android.
Widget _app(
  void Function(ScaffoldMessengerState messenger) show, {
  bool screenReader = false,
  bool reduceMotion = false,
  RecommendedTimeouts asked = RecommendedTimeouts.none,
}) => RecommendedTimeoutsScope(
  timeouts: asked,
  child: MaterialApp(
    theme: BipaTheme.light,
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(accessibleNavigation: screenReader, disableAnimations: reduceMotion),
        child: ScaffoldMessenger(
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(onPressed: () => show(ScaffoldMessenger.of(context)), child: const Text('mostrar')),
              ),
            ),
          ),
        ),
      ),
    ),
  ),
);

Finder get _timer => find.byKey(const ValueKey('bipa-toast-timer'));

/// Quanto da linha do tempo ainda resta, de 0 a 1.
double _timeLeft(WidgetTester tester) => tester.getSize(_timer).width / tester.getSize(find.byType(BipaToast)).width;

/// Mostra o aviso e espera ele terminar de entrar (250 ms), sem o
/// `pumpAndSettle`, que andaria a linha do tempo até o fim.
Future<void> _show(WidgetTester tester) async {
  await tester.tap(find.text('mostrar'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  testWidgets('o aviso com Desfazer some sozinho depois de 4 s, com a linha do tempo esvaziando', (tester) async {
    await tester.pumpWidget(
      _app((m) => showBipaToast(m, 'Leite foi para a lista', actionLabel: 'Desfazer', onAction: () {})),
    );
    await _show(tester);

    expect(find.text('Leite foi para a lista'), findsOneWidget);
    expect(_timer, findsOneWidget);
    // A linha começa a contar quando o aviso termina de entrar, junto com o
    // relógio do ScaffoldMessenger.
    await tester.pump(const Duration(seconds: 2));
    expect(_timeLeft(tester), closeTo(0.5, 0.05));

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Leite foi para a lista'), findsNothing);
  });

  testWidgets('a duração longa (ações grandes) vale para o aviso e para a linha do tempo (H13)', (tester) async {
    await tester.pumpWidget(
      _app(
        (m) => showBipaToast(
          m,
          'Compra terminada',
          actionLabel: 'Desfazer',
          onAction: () {},
          duration: BipaToastDuration.long,
        ),
      ),
    );
    await _show(tester);

    await tester.pump(const Duration(seconds: 5));
    expect(_timeLeft(tester), closeTo(0.5, 0.05));
    await tester.pump(const Duration(milliseconds: 4900));
    expect(find.text('Compra terminada'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.text('Compra terminada'), findsNothing);
  });

  group('o dedo sobre o aviso para o tempo (H13)', () {
    testWidgets('segurar para o relógio e a linha; soltar volta de onde parou', (tester) async {
      await tester.pumpWidget(
        _app((m) => showBipaToast(m, '14 itens saíram da lista', actionLabel: 'Desfazer', onAction: () {})),
      );
      await _show(tester);
      await tester.pump(const Duration(seconds: 2));

      final finger = await tester.startGesture(tester.getCenter(find.text('14 itens saíram da lista')));
      await tester.pump(const Duration(seconds: 30));
      expect(find.text('14 itens saíram da lista'), findsOneWidget);
      expect(_timeLeft(tester), closeTo(0.5, 0.05));

      await finger.up();
      await tester.pump(const Duration(milliseconds: 1900));
      expect(find.text('14 itens saíram da lista'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(find.text('14 itens saíram da lista'), findsNothing);
    });

    testWidgets('segurar ainda na entrada adia o começo até soltar', (tester) async {
      await tester.pumpWidget(
        _app((m) => showBipaToast(m, 'Leite saiu da lista', actionLabel: 'Desfazer', onAction: () {})),
      );
      await tester.tap(find.text('mostrar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final finger = await tester.startGesture(tester.getCenter(find.text('Leite saiu da lista')));
      await tester.pump(const Duration(seconds: 10));
      expect(_timeLeft(tester), 1);

      await finger.up();
      await tester.pump(const Duration(seconds: 2));
      expect(_timeLeft(tester), closeTo(0.5, 0.05));
    });

    testWidgets('o Desfazer tocado no fim ainda vale', (tester) async {
      var undone = 0;
      await tester.pumpWidget(
        _app((m) => showBipaToast(m, 'Leite saiu da lista', actionLabel: 'Desfazer', onAction: () => undone++)),
      );
      await _show(tester);
      await tester.pump(const Duration(milliseconds: 3900));

      // O dedo desce a 100 ms do fim e fica um tempo antes de subir.
      final finger = await tester.startGesture(tester.getCenter(find.text('Desfazer')));
      await tester.pump(const Duration(seconds: 1));
      await finger.up();
      await tester.pumpAndSettle();

      expect(undone, 1);
    });
  });

  group('o "Tempo para agir" do Android (H13)', () {
    testWidgets('estica o aviso com Desfazer até o tempo pedido', (tester) async {
      await tester.pumpWidget(
        _app(
          (m) => showBipaToast(m, 'Leite foi para a lista', actionLabel: 'Desfazer', onAction: () {}),
          asked: const RecommendedTimeouts(controls: Duration(seconds: 30)),
        ),
      );
      await _show(tester);

      await tester.pump(const Duration(seconds: 15));
      expect(_timeLeft(tester), closeTo(0.5, 0.05));
      await tester.pump(const Duration(milliseconds: 14900));
      expect(find.text('Leite foi para a lista'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(find.text('Leite foi para a lista'), findsNothing);
    });

    testWidgets('estica o aviso só de texto pelo tempo de leitura', (tester) async {
      await tester.pumpWidget(
        _app(
          (m) => showBipaToast(m, 'Não deu para salvar'),
          asked: const RecommendedTimeouts(text: Duration(seconds: 20)),
        ),
      );
      await _show(tester);

      await tester.pump(const Duration(seconds: 19));
      expect(find.text('Não deu para salvar'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('Não deu para salvar'), findsNothing);
    });

    testWidgets('um tempo pedido menor que o do aviso não o encurta', (tester) async {
      await tester.pumpWidget(
        _app(
          (m) => showBipaToast(
            m,
            'Compra terminada',
            actionLabel: 'Desfazer',
            onAction: () {},
            duration: BipaToastDuration.long,
          ),
          asked: const RecommendedTimeouts(controls: Duration(seconds: 5), text: Duration(seconds: 5)),
        ),
      );
      await _show(tester);

      await tester.pump(const Duration(seconds: 9));
      expect(find.text('Compra terminada'), findsOneWidget);
    });

    testWidgets('com o leitor de tela, o aviso com Desfazer continua esperando a pessoa', (tester) async {
      await tester.pumpWidget(
        _app(
          (m) => showBipaToast(m, 'Leite foi para a lista', actionLabel: 'Desfazer', onAction: () {}),
          screenReader: true,
          asked: const RecommendedTimeouts(controls: Duration(seconds: 30)),
        ),
      );
      await _show(tester);

      await tester.pump(const Duration(minutes: 2));
      expect(find.text('Leite foi para a lista'), findsOneWidget);
    });

    testWidgets('vale também para o aviso do visor da câmera', (tester) async {
      late BuildContext captured;
      await tester.pumpWidget(
        RecommendedTimeoutsScope(
          timeouts: const RecommendedTimeouts(controls: Duration(seconds: 30)),
          child: Builder(
            builder: (context) {
              captured = context;
              return const SizedBox();
            },
          ),
        ),
      );
      var cleared = 0;
      BipaNoticeTimer().start(
        captured,
        hasAction: true,
        duration: BipaToastDuration.short.time,
        onTimeout: () => cleared++,
      );

      await tester.pump(const Duration(seconds: 29));
      expect(cleared, 0);
      await tester.pump(const Duration(seconds: 1));
      expect(cleared, 1);
    });
  });

  testWidgets('com o leitor de tela, o aviso com Desfazer fica até o toque, sem a linha do tempo', (tester) async {
    var undone = 0;
    await tester.pumpWidget(
      _app(
        (m) => showBipaToast(m, 'Leite foi para a lista', actionLabel: 'Desfazer', onAction: () => undone++),
        screenReader: true,
      ),
    );
    await _show(tester);

    expect(_timer, findsNothing);
    await tester.pump(const Duration(seconds: 30));
    expect(find.text('Leite foi para a lista'), findsOneWidget);

    await tester.tap(find.text('Desfazer'));
    await tester.pumpAndSettle();
    expect(undone, 1);
    expect(find.text('Leite foi para a lista'), findsNothing);
  });

  testWidgets('com "Remover animações", a linha do tempo não aparece, e o tempo continua valendo (H14)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        (m) => showBipaToast(m, 'Leite foi para a lista', actionLabel: 'Desfazer', onAction: () {}),
        reduceMotion: true,
      ),
    );
    await _show(tester);

    expect(_timer, findsNothing);
    await tester.pump(BipaToastDuration.short.time - const Duration(milliseconds: 100));
    expect(find.text('Desfazer'), findsOneWidget, reason: 'o Desfazer vale os 4 s inteiros');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.text('Leite foi para a lista'), findsNothing);
  });

  testWidgets('a linha do tempo é um relógio: não encurta quando o sistema pede menos animação', (tester) async {
    await tester.pumpWidget(
      _app((m) => showBipaToast(m, 'Leite foi para a lista', actionLabel: 'Desfazer', onAction: () {})),
    );
    final binding = tester.binding;
    binding.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
      disableAnimations: true,
    );
    addTearDown(binding.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await _show(tester);

    await tester.pump(const Duration(seconds: 2));
    expect(_timeLeft(tester), closeTo(0.5, 0.05));
  });

  testWidgets('Desfazer chama a ação uma vez só e fecha o aviso', (tester) async {
    var undone = 0;
    late ScaffoldFeatureController<SnackBar, SnackBarClosedReason> controller;
    await tester.pumpWidget(
      _app(
        (m) => controller = showBipaToast(m, 'Leite saiu da lista', actionLabel: 'Desfazer', onAction: () => undone++),
      ),
    );
    await _show(tester);

    await tester.tap(find.text('Desfazer'));
    await tester.tap(find.text('Desfazer'));
    await tester.pumpAndSettle();

    expect(undone, 1);
    expect(await controller.closed, SnackBarClosedReason.action);
  });

  testWidgets('o aviso sem ação não tem linha do tempo e some depois de 4 s', (tester) async {
    await tester.pumpWidget(_app((m) => showBipaToast(m, 'Não deu para salvar')));
    await _show(tester);

    expect(_timer, findsNothing);
    expect(find.byType(TextButton), findsOneWidget, reason: 'só o botão da tela, sem ação no aviso');
    await tester.pump(BipaToastDuration.short.time);
    await tester.pumpAndSettle();
    expect(find.text('Não deu para salvar'), findsNothing);
  });

  testWidgets('um aviso novo toma o lugar do anterior', (tester) async {
    var count = 0;
    await tester.pumpWidget(_app((m) => showBipaToast(m, 'Aviso ${++count}')));
    await _show(tester);
    await _show(tester);
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Aviso 1'), findsNothing);
    expect(find.text('Aviso 2'), findsOneWidget);
  });

  group('aviso que não é snackbar (o do visor da câmera)', () {
    /// Um contexto com o leitor de tela ligado ou não.
    Future<BuildContext> contextWith(WidgetTester tester, {required bool screenReader}) async {
      late BuildContext captured;
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(accessibleNavigation: screenReader),
          child: Builder(
            builder: (context) {
              captured = context;
              return const SizedBox();
            },
          ),
        ),
      );
      return captured;
    }

    testWidgets('sem leitor de tela, o aviso com botão sai no tempo pedido', (tester) async {
      final context = await contextWith(tester, screenReader: false);
      final timer = BipaNoticeTimer();
      var cleared = 0;

      final timed = timer.start(
        context,
        hasAction: true,
        duration: BipaToastDuration.short.time,
        onTimeout: () => cleared++,
      );

      expect(timed, isTrue);
      await tester.pump(BipaToastDuration.short.time - const Duration(milliseconds: 1));
      expect(cleared, 0);
      await tester.pump(const Duration(milliseconds: 1));
      expect(cleared, 1);
    });

    testWidgets('com o leitor de tela, o aviso com botão ("trocar o local", "Desfazer") espera a pessoa', (
      tester,
    ) async {
      final context = await contextWith(tester, screenReader: true);
      final timer = BipaNoticeTimer();
      var cleared = 0;

      final timed = timer.start(
        context,
        hasAction: true,
        duration: BipaToastDuration.short.time,
        onTimeout: () => cleared++,
      );

      expect(timed, isFalse);
      expect(bipaToastTimeout(context, hasAction: true), isNull);
      await tester.pump(const Duration(minutes: 1));
      expect(cleared, 0);
    });

    testWidgets('com o leitor de tela, o aviso só de texto ainda sai sozinho', (tester) async {
      final context = await contextWith(tester, screenReader: true);
      final timer = BipaNoticeTimer();
      var cleared = 0;

      timer.start(context, hasAction: false, duration: const Duration(milliseconds: 2500), onTimeout: () => cleared++);

      await tester.pump(const Duration(milliseconds: 2500));
      expect(cleared, 1);
    });

    testWidgets('um aviso novo recomeça o relógio, e cancelar o para', (tester) async {
      final context = await contextWith(tester, screenReader: false);
      final timer = BipaNoticeTimer();
      var cleared = 0;

      timer.start(context, hasAction: false, duration: const Duration(seconds: 2), onTimeout: () => cleared++);
      await tester.pump(const Duration(seconds: 1));
      timer.start(context, hasAction: false, duration: const Duration(seconds: 2), onTimeout: () => cleared++);
      await tester.pump(const Duration(seconds: 1));
      expect(cleared, 0);
      timer.cancel();
      await tester.pump(const Duration(seconds: 5));
      expect(cleared, 0);
    });
  });

  testWidgets('o aviso tem o raio de cartão do design system, não a pílula', (tester) async {
    await tester.pumpWidget(_app((m) => showBipaToast(m, 'Bipou!')));
    await _show(tester);

    final material = tester.widget<Material>(
      find.descendant(of: find.byType(SnackBar), matching: find.byType(Material)).first,
    );
    expect(material.shape, RoundedRectangleBorder(borderRadius: BorderRadius.circular(BipaRadius.lg)));
  });
}
