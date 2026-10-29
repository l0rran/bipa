import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/core/money/money.dart';
import 'package:bipa/core/widgets/weighed_value_dialog.dart';
import 'package:bipa/features/shopping_list/domain/weighing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// A conta de volta como a bandeja a monta: o peso que o valor dá a R$ 8,99/kg.
WeighedBack? _back(Money value) {
  const perKilo = Money.cents(899);
  final grams = weightInGrams(value, perKilo);
  if (grams == null) return null;
  final weight = formatWeight(grams);
  return (text: '$weight a R\$ 8,99/kg', spoken: '$weight a R\$ 8,99 o quilo');
}

/// Abre o diálogo por um botão e entrega o que ele devolveu a [onResult].
Future<void> _open(
  WidgetTester tester, {
  required void Function(Money?) onResult,
  WeighedBack? Function(Money value) backFor = _back,
  Money? initial,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: BipaTheme.light,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async => onResult(
                await showWeighedValueDialog(
                  context,
                  title: 'Quanto deu o Tomate italiano?',
                  backFor: backFor,
                  initial: initial,
                ),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('pergunta quanto deu e mostra o peso que o valor dá pelo preço por kg', (tester) async {
    final semantics = tester.ensureSemantics();
    Money? result;
    var closed = false;
    await _open(
      tester,
      onResult: (value) {
        result = value;
        closed = true;
      },
    );

    expect(find.text('Quanto deu o Tomate italiano?'), findsOneWidget);
    // Sem valor, não há conta a mostrar.
    expect(find.textContaining('kg a'), findsNothing);

    await tester.enterText(find.byType(TextField), '12,40');
    await tester.pump();
    expect(find.text(r'1,38 kg a R$ 8,99/kg'), findsOneWidget);
    expect(find.bySemanticsLabel(r'1,38 kg a R$ 8,99 o quilo'), findsOneWidget);

    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    expect(result, const Money.cents(1240));
    semantics.dispose();
  });

  testWidgets('a conta de volta acompanha o que se digita', (tester) async {
    await _open(tester, onResult: (_) {});
    await tester.enterText(find.byType(TextField), '8,99');
    await tester.pump();
    expect(find.text(r'1,00 kg a R$ 8,99/kg'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '4,50');
    await tester.pump();
    expect(find.text(r'501 g a R$ 8,99/kg'), findsOneWidget);
    // Um valor que não é dinheiro apaga a conta.
    await tester.enterText(find.byType(TextField), 'abc');
    await tester.pump();
    expect(find.byIcon(Icons.scale_outlined), findsNothing);
  });

  testWidgets('sem preço por quilo, o diálogo é só o campo', (tester) async {
    Money? result;
    await _open(tester, onResult: (value) => result = value, backFor: (_) => null);

    await tester.enterText(find.byType(TextField), '12,40');
    await tester.pump();
    expect(find.byIcon(Icons.scale_outlined), findsNothing);

    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(result, const Money.cents(1240));
  });

  testWidgets('o campo vem com o valor de antes, e o teclado confirma', (tester) async {
    Money? result;
    await _open(tester, onResult: (value) => result = value, initial: const Money.cents(1240));

    expect(find.text('12,40'), findsOneWidget);
    // Já abre com a conta do valor de antes.
    expect(find.text(r'1,38 kg a R$ 8,99/kg'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '13,00');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(result, const Money.cents(1300));
  });

  testWidgets('"Cancelar" e um valor que não vale não devolvem nada', (tester) async {
    Money? result = const Money.cents(1);
    var closed = false;
    await _open(
      tester,
      onResult: (value) {
        result = value;
        closed = true;
      },
    );

    // Vazio ou zero: "Salvar" não fecha.
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(closed, isFalse);
    await tester.enterText(find.byType(TextField), '0,00');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(closed, isFalse);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    expect(result, isNull);
  });
}
