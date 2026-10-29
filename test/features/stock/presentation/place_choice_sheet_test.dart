import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/features/stock/domain/stock_location.dart';
import 'package:bipa/features/stock/presentation/place_choice_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Abre a folha por cima de uma tela e guarda o que ela devolveu.
Future<List<StockLocation?>> _open(WidgetTester tester, StockLocation current) async {
  final results = <StockLocation?>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: BipaTheme.light,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async =>
                results.add(await pickStockLocation(context, productName: 'Leite integral 1 L', current: current)),
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
  return results;
}

void main() {
  testWidgets('a folha pergunta onde fica, com o local atual marcado', (tester) async {
    final semantics = tester.ensureSemantics();
    await _open(tester, StockLocation.pantry);

    expect(find.text('Onde fica Leite integral 1 L?'), findsOneWidget);
    for (final label in ['Despensa', 'Geladeira', 'Freezer', 'Banheiro', 'Limpeza', 'Outros']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(
      tester.getSemantics(find.bySemanticsLabel('Despensa')),
      matchesSemantics(
        label: 'Despensa',
        isButton: true,
        hasCheckedState: true,
        isChecked: true,
        isInMutuallyExclusiveGroup: true,
        hasTapAction: true,
      ),
    );
    // O marcado mostra o visto no lugar do ícone.
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('tocar num local fecha a folha e devolve a escolha', (tester) async {
    final results = await _open(tester, StockLocation.pantry);

    await tester.tap(find.text('Geladeira'));
    await tester.pumpAndSettle();

    expect(results, [StockLocation.fridge]);
    expect(find.text('Onde fica Leite integral 1 L?'), findsNothing);
  });

  testWidgets('fechar sem escolher devolve nada', (tester) async {
    final results = await _open(tester, StockLocation.fridge);

    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    expect(results, [null]);
  });
}
