import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/design_system/components/quantity_stepper.dart';
import 'package:bipa/core/design_system/components/stock_gauge.dart';
import 'package:bipa/core/design_system/components/stock_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) => MaterialApp(theme: BipaTheme.light, home: Scaffold(body: Center(child: child)));

void main() {
  testWidgets('o medidor mostra o número e diz o estado ao leitor de tela', (tester) async {
    final semantics = tester.ensureSemantics();
    addTearDown(semantics.dispose);
    await tester.pumpWidget(
      _app(const StockGauge(quantityLabel: '2', state: GaugeState.low, fraction: 0.5, semanticsLabel: '2 de 4 un')),
    );
    await tester.pumpAndSettle();

    expect(find.text('2'), findsOneWidget);
    expect(find.bySemanticsLabel('2 de 4 un'), findsOneWidget);
  });

  testWidgets('o stepper soma e dá baixa; sem onDecrement, o − não faz nada', (tester) async {
    final semantics = tester.ensureSemantics();
    addTearDown(semantics.dispose);
    var value = 1;
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) => QuantityStepper(
            value: '$value',
            unit: 'un',
            decrementLabel: 'Usei um',
            incrementLabel: 'Comprei um',
            onIncrement: () => setState(() => value++),
            onDecrement: value > 0 ? () => setState(() => value--) : null,
          ),
        ),
      ),
    );

    await tester.tap(find.bySemanticsLabel('Comprei um'));
    await tester.pumpAndSettle();
    expect(value, 2);

    await tester.tap(find.bySemanticsLabel('Usei um'));
    await tester.tap(find.bySemanticsLabel('Usei um'));
    await tester.pumpAndSettle();
    expect(value, 0);

    await tester.tap(find.bySemanticsLabel('Usei um'));
    await tester.pumpAndSettle();
    expect(value, 0);
  });

  testWidgets('a linha do estoque abre o editor só quando expandida', (tester) async {
    Widget row({required bool expanded}) => _app(
      StockList(
        children: [
          StockRow(
            id: 'cafe',
            thumb: const SizedBox.square(dimension: 44),
            name: 'Café Pilão 500 g',
            gauge: const SizedBox.square(dimension: 40),
            expanded: expanded,
            onTap: () {},
            editor: const Text('editor'),
          ),
        ],
      ),
    );

    await tester.pumpWidget(row(expanded: false));
    expect(find.text('editor'), findsNothing);

    await tester.pumpWidget(row(expanded: true));
    await tester.pumpAndSettle();
    expect(find.text('editor'), findsOneWidget);
  });

  testWidgets('deslizar para a esquerda dispara a baixa e a linha não some', (tester) async {
    var used = 0;
    await tester.pumpWidget(
      _app(
        SizedBox(
          width: 360,
          child: StockList(
            children: [
              StockRow(
                id: 'cafe',
                thumb: const SizedBox.square(dimension: 44),
                name: 'Café Pilão 500 g',
                gauge: const SizedBox.square(dimension: 40),
                expanded: false,
                onTap: () {},
                swipeLeft: StockSwipeAction(label: 'Usei um', icon: Icons.remove, onTriggered: () => used++),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.drag(find.text('Café Pilão 500 g'), const Offset(-300, 0));
    await tester.pumpAndSettle();

    expect(used, 1);
    expect(find.text('Café Pilão 500 g'), findsOneWidget);
  });
}
