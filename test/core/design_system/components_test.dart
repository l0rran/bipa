import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/design_system/components/dropdown_chip.dart';
import 'package:bipa/core/design_system/components/price_history.dart';
import 'package:bipa/core/design_system/components/quantity_stepper.dart';
import 'package:bipa/core/design_system/components/scan_tray.dart';
import 'package:bipa/core/design_system/components/shopping_list.dart';
import 'package:bipa/core/design_system/components/stock_gauge.dart';
import 'package:bipa/core/design_system/components/stock_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) => MaterialApp(theme: BipaTheme.light, home: Scaffold(body: Center(child: child)));

void main() {
  testWidgets('o medidor mostra o número e diz o estado ao leitor de tela', (tester) async {
    // O handle precisa ser descartado dentro do teste: o flutter_test confere
    // isso antes de rodar os addTearDown.
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(const StockGauge(quantityLabel: '2', state: GaugeState.low, fraction: 0.5, semanticsLabel: '2 de 4 un')),
    );
    await tester.pumpAndSettle();

    expect(find.text('2'), findsOneWidget);
    expect(find.bySemanticsLabel('2 de 4 un'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('o stepper soma e dá baixa; sem onDecrement, o − não faz nada', (tester) async {
    final semantics = tester.ensureSemantics();
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
    semantics.dispose();
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

  testWidgets('o item da lista marca e desmarca ao toque, com o preço no rótulo', (tester) async {
    final semantics = tester.ensureSemantics();
    var checked = false;
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) => ShoppingListRow(
            name: 'Café Pilão',
            price: '≈ 18,99',
            checked: checked,
            onChanged: (value) => setState(() => checked = value),
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Café Pilão, ≈ 18,99'), findsOneWidget);
    await tester.tap(find.text('Café Pilão'));
    await tester.pumpAndSettle();
    expect(checked, isTrue);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);

    await tester.tap(find.text('Café Pilão'));
    await tester.pumpAndSettle();
    expect(checked, isFalse);
    semantics.dispose();
  });

  testWidgets('a prévia da lista mostra o número, o total e o "+N" das miniaturas', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      _app(
        ListPreviewCard(
          count: 7,
          countLabel: 'itens',
          estimate: '≈ R\$ 84,30',
          thumbs: const [Icon(Icons.coffee_outlined), Icon(Icons.egg_outlined), Icon(Icons.eco_outlined)],
          extraCount: 4,
          actionLabel: 'Abrir a lista',
          actionIcon: Icons.checklist_rounded,
          semanticLabel: 'Lista de compras: 7 itens',
          onTap: () => tapped = true,
        ),
      ),
    );

    expect(find.text('≈ R\$ 84,30'), findsOneWidget);
    expect(find.text('+4'), findsOneWidget);
    await tester.tap(find.text('Abrir a lista'));
    expect(tapped, isTrue);
  });

  testWidgets('a barra da compra mostra o progresso e o total e leva à lista', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      _app(
        ShoppingBar(
          title: '3 de 7 itens',
          subtitle: 'R\$ 32,10 · Atacarejo',
          actionLabel: 'Continuar',
          progress: 3 / 7,
          semanticLabel: 'Compra em andamento: 3 de 7',
          onTap: () => tapped = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('3 de 7 itens'), findsOneWidget);
    expect(find.text('R\$ 32,10 · Atacarejo'), findsOneWidget);
    await tester.tap(find.text('Continuar'));
    expect(tapped, isTrue);
  });

  testWidgets('o item da bandeja liga e desliga o levar e abre o preço', (tester) async {
    final semantics = tester.ensureSemantics();
    var take = true;
    var priceTaps = 0;
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) => ScanTrayItem(
            name: '2× Café Pilão',
            take: take,
            takeLabel: 'Levar Café Pilão',
            onTakeChanged: (value) => setState(() => take = value),
            priceTapLabel: 'Digitar o preço',
            onPriceTap: () => priceTaps++,
          ),
        ),
      ),
    );

    expect(find.text('—'), findsOneWidget);
    await tester.tap(find.text('—'));
    expect(priceTaps, 1);

    await tester.tap(find.bySemanticsLabel('Levar Café Pilão'));
    await tester.pumpAndSettle();
    expect(take, isFalse);
    semantics.dispose();
  });

  testWidgets('o aviso da leitura ao vivo mostra o preço e o destino, e o leitor de tela ouve os dois', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(const LiveReadChip(icon: Icons.sell_outlined, price: r'R$ 27,90', detail: 'Arroz Tio João 5 kg')),
    );

    expect(find.text(r'R$ 27,90'), findsOneWidget);
    expect(find.text('Arroz Tio João 5 kg'), findsOneWidget);
    expect(find.bySemanticsLabel(r'R$ 27,90, Arroz Tio João 5 kg'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('o gráfico de preço mostra os meses e se descreve ao leitor de tela', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        const SizedBox(
          width: 320,
          child: PriceHistoryChart(
            points: [Offset(0, 1), Offset(0.5, 0.4), Offset(1, 0)],
            axisLabels: ['mai', 'jul', 'set', 'hoje'],
            semanticsLabel: r'Preço do kg nos últimos 6 meses, de R$ 5,90 a R$ 4,99',
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel(r'Preço do kg nos últimos 6 meses, de R$ 5,90 a R$ 4,99'), findsOneWidget);
    // Os meses ficam por baixo do rótulo: o leitor de tela ouve só a frase.
    expect(find.text('hoje'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('o chip de escolha mostra o valor, abre ao tocar e tem rótulo próprio', (tester) async {
    final semantics = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(
      _app(
        DropdownChip(
          icon: Icons.storefront_outlined,
          label: 'Atacarejo',
          semanticsLabel: 'Mercado da lista: Atacarejo. Trocar',
          onTap: () => taps++,
        ),
      ),
    );

    expect(find.text('Atacarejo'), findsOneWidget);
    await tester.tap(find.byType(DropdownChip));
    expect(taps, 1);
    expect(find.bySemanticsLabel('Mercado da lista: Atacarejo. Trocar'), findsOneWidget);
    semantics.dispose();
  });
}
