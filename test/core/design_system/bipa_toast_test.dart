import 'package:bipa/core/design_system/bipa_metrics.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/design_system/components/bipa_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Uma tela com um botão que mostra o aviso. [screenReader] liga o
/// `accessibleNavigation`, como o TalkBack.
Widget _app(void Function(ScaffoldMessengerState messenger) show, {bool screenReader = false}) => MaterialApp(
  theme: BipaTheme.light,
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(accessibleNavigation: screenReader),
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

  testWidgets('a duração própria vale para o aviso e para a linha do tempo', (tester) async {
    await tester.pumpWidget(
      _app(
        (m) => showBipaToast(
          m,
          'Compra terminada',
          actionLabel: 'Desfazer',
          onAction: () {},
          duration: const Duration(seconds: 6),
        ),
      ),
    );
    await _show(tester);

    await tester.pump(const Duration(seconds: 3));
    expect(_timeLeft(tester), closeTo(0.5, 0.05));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Compra terminada'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Compra terminada'), findsNothing);
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
    await tester.pump(bipaToastDuration);
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

  testWidgets('o aviso tem o raio de cartão do design system, não a pílula', (tester) async {
    await tester.pumpWidget(_app((m) => showBipaToast(m, 'Bipou!')));
    await _show(tester);

    final material = tester.widget<Material>(
      find.descendant(of: find.byType(SnackBar), matching: find.byType(Material)).first,
    );
    expect(material.shape, RoundedRectangleBorder(borderRadius: BorderRadius.circular(BipaRadius.lg)));
  });
}
