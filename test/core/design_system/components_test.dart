import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/design_system/components/camera_mode_switch.dart';
import 'package:bipa/core/design_system/components/dropdown_chip.dart';
import 'package:bipa/core/design_system/components/error_line.dart';
import 'package:bipa/core/design_system/components/list_cost_compare.dart';
import 'package:bipa/core/design_system/components/market_map.dart';
import 'package:bipa/core/design_system/components/place_filter.dart';
import 'package:bipa/core/design_system/components/price_history.dart';
import 'package:bipa/core/design_system/components/quantity_stepper.dart';
import 'package:bipa/core/design_system/components/scan_menu.dart';
import 'package:bipa/core/design_system/components/scan_tray.dart';
import 'package:bipa/core/design_system/components/shopping_list.dart';
import 'package:bipa/core/design_system/components/stock_gauge.dart';
import 'package:bipa/core/design_system/components/stock_list.dart';
import 'package:bipa/core/design_system/components/tap_target.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) => MaterialApp(
  theme: BipaTheme.light,
  home: Scaffold(body: Center(child: child)),
);

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

    // O círculo tem 40, mas a área de toque tem 48×48.
    expect(tester.getSize(find.bySemanticsLabel('Comprei um')), const Size(48, 48));
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

  testWidgets('o item da lista mostra a quantidade antes do nome, e tocar nela a muda sem marcar', (tester) async {
    final semantics = tester.ensureSemantics();
    var longPresses = 0;
    var quantityTaps = 0;
    bool? checked;
    await tester.pumpWidget(
      _app(
        ShoppingListRow(
          name: 'Leite',
          quantity: '3×',
          quantitySpoken: '3 embalagens',
          price: '4,79',
          checked: false,
          onChanged: (value) => checked = value,
          onQuantityTap: () => quantityTaps++,
          onLongPress: () => longPresses++,
        ),
      ),
    );

    expect(find.text('3×'), findsOneWidget);
    expect(find.bySemanticsLabel('Leite, 3 embalagens, 4,79'), findsOneWidget);
    await tester.tap(find.text('3×'));
    expect((quantityTaps, checked), (1, null));
    await tester.tap(find.text('Leite'));
    expect(checked, isTrue);
    await tester.longPress(find.text('Leite'));
    expect(longPresses, 1);
    final target = find.ancestor(of: find.text('3×'), matching: find.byType(TapTarget));
    expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
    // O alvo maior não muda a altura da linha.
    expect(tester.getSize(find.byType(ShoppingListRow)).height, 52);
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

  testWidgets('com letra grande, a barra, o bloco e os locais crescem em vez de cortar o texto', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    Widget large(Widget child) => _app(child);

    await tester.pumpWidget(
      large(
        ShoppingBar(
          title: '3 de 7 itens',
          subtitle: 'R\$ 32,10 · Atacarejo',
          actionLabel: 'Continuar',
          progress: 3 / 7,
          semanticLabel: 'Compra em andamento: 3 de 7',
          onTap: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(ShoppingBar)).height, greaterThan(60));

    await tester.pumpWidget(
      large(QuickTile(icon: Icons.coffee_outlined, label: 'Café', selected: false, onTap: () {})),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(QuickTile)).height, greaterThan(76));

    await tester.pumpWidget(
      large(
        PlaceFilter<int>(
          options: const [PlaceOption(value: 0, label: 'Despensa', icon: Icons.kitchen_outlined, count: 3)],
          selected: 0,
          onSelected: (_) {},
        ),
      ),
    );
    expect(tester.takeException(), isNull);
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
    // O interruptor é pequeno, mas a área de toque tem 48×48.
    expect(tester.getSize(find.byType(BipaToggle)), const Size(48, 48));
    semantics.dispose();
  });

  testWidgets('o item com preço estimado e quantidade: o nome abre a quantidade', (tester) async {
    final semantics = tester.ensureSemantics();
    var nameTaps = 0;
    await tester.pumpWidget(
      _app(
        ScanTrayItem(
          name: 'Café Pilão',
          price: r'R$ 18,99',
          priceEstimated: true,
          priceSemanticsLabel: r'R$ 18,99, estimado',
          take: true,
          takeLabel: 'Levar Café Pilão',
          onTakeChanged: (_) {},
          priceTapLabel: 'Digitar o preço',
          onPriceTap: () {},
          onNameTap: () => nameTaps++,
          nameTapLabel: 'Quantidade de Café Pilão',
        ),
      ),
    );

    // Na tela, só a etiqueta vazada diz que é estimado; o leitor de tela ouve.
    expect(find.text(r'R$ 18,99'), findsOneWidget);
    expect(find.bySemanticsLabel(r'R$ 18,99, estimado'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Quantidade de Café Pilão'));
    expect(nameTaps, 1);
    semantics.dispose();
  });

  testWidgets('a alça da bandeja segue a direção do arrasto', (tester) async {
    final semantics = tester.ensureSemantics();
    var toggles = 0;
    Future<void> pump({required bool expanded}) => tester.pumpWidget(
      _app(
        ScanTray(
          title: 'Carrinho',
          totalLabel: 'Vou levar',
          items: const [],
          footer: const SizedBox(),
          handleLabel: 'Alça',
          onHandleTap: () => toggles++,
          expanded: expanded,
        ),
      ),
    );

    await pump(expanded: false);
    await tester.fling(find.bySemanticsLabel('Alça'), const Offset(0, 60), 800);
    expect(toggles, 0, reason: 'recolhida, puxar para baixo não faz nada');
    await tester.fling(find.bySemanticsLabel('Alça'), const Offset(0, -60), 800);
    expect(toggles, 1);

    await pump(expanded: true);
    await tester.fling(find.bySemanticsLabel('Alça'), const Offset(0, -60), 800);
    expect(toggles, 1, reason: 'expandida, puxar para cima não faz nada');
    await tester.fling(find.bySemanticsLabel('Alça'), const Offset(0, 60), 800);
    expect(toggles, 2);
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
            axisLabels: [
              (label: 'mai', at: 0),
              (label: 'jul', at: 0.4),
              (label: 'set', at: 0.8),
              (label: 'hoje', at: 1),
            ],
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
    // O chip tem 40 de altura, mas a área de toque tem 48, e a folga também vale.
    expect(tester.getSize(find.byType(DropdownChip)).height, 48);
    await tester.tapAt(tester.getTopLeft(find.byType(DropdownChip)) + const Offset(24, 2));
    expect(taps, 2);
    expect(find.bySemanticsLabel('Mercado da lista: Atacarejo. Trocar'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('o mapa desenha os mercados sem cortar e se descreve ao leitor de tela', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        const SizedBox(
          width: 358,
          child: MarketMap(
            pins: [
              MarketMapPin(east: 40, north: 30, here: true, best: true),
              MarketMapPin(east: -600, north: 400),
              MarketMapPin(east: 1800, north: -900),
            ],
            semanticsLabel: 'Mapa com 3 mercados perto de você',
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Mapa com 3 mercados perto de você'), findsOneWidget);
    expect(find.byIcon(Icons.storefront_rounded), findsNWidgets(3));
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('a comparação marca só o primeiro como mais barato e mostra a ressalva', (tester) async {
    await tester.pumpWidget(
      _app(
        const SizedBox(
          width: 358,
          child: ListCostCompare(
            bestLabel: 'mais barato',
            rows: [
              ListCostRow(name: 'Atacarejo', value: r'R$ 84,30', fraction: 0.86),
              ListCostRow(name: 'Bairro', value: r'R$ 61,70', fraction: 0.63, note: 'sem preço de 2 itens'),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('mais barato', findRichText: true), findsOneWidget);
    expect(find.text('sem preço de 2 itens'), findsOneWidget);
  });

  testWidgets('o seletor da câmera marca o modo escolhido e troca no toque', (tester) async {
    final semantics = tester.ensureSemantics();
    var selected = 0;
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) => CameraModeSwitch<int>(
            options: const [(value: 0, label: 'Etiqueta'), (value: 1, label: 'Código')],
            selected: selected,
            onSelected: (value) => setState(() => selected = value),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Código'));
    await tester.pumpAndSettle();
    expect(selected, 1);
    expect(tester.getSize(find.bySemanticsLabel('Código')).height, greaterThanOrEqualTo(48));
    semantics.dispose();
  });

  testWidgets('o menu do bipar devolve a opção tocada e fecha no "×"', (tester) async {
    String? chosen;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              chosen = await showScanMenu<String>(
                context,
                closeLabel: 'Fechar',
                items: const [
                  (value: 'cart', icon: Icons.shopping_cart_outlined, label: 'Modo carrinho', hint: 'vários seguidos'),
                  (value: 'used', icon: Icons.home_outlined, label: 'Dar baixa em casa', hint: null),
                ],
              );
            },
            child: const Text('abrir'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.text('vários seguidos'), findsOneWidget);
    await tester.tap(find.text('Dar baixa em casa'));
    await tester.pumpAndSettle();
    expect(chosen, 'used');
  });

  testWidgets('o aviso da câmera sem valor mostra só o texto', (tester) async {
    await tester.pumpWidget(_app(const LiveReadChip(icon: Icons.add_rounded, detail: 'Café · 3 em casa')));

    expect(find.text('Café · 3 em casa'), findsOneWidget);
    expect(find.bySemanticsLabel('Café · 3 em casa'), findsOneWidget);
  });

  testWidgets('o erro vem com o ícone, não só com a cor', (tester) async {
    await tester.pumpWidget(_app(const ErrorLine('Escolha o mercado para registrar o preço.')));

    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    expect(find.text('Escolha o mercado para registrar o preço.'), findsOneWidget);
  });

  testWidgets('o aviso da câmera tocável mostra a seta e responde no toque', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _app(
        LiveReadChip(icon: Icons.sell_outlined, price: r'R$ 8,99/kg', detail: 'Tomate italiano?', onTap: () => taps++),
      ),
    );

    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    expect(tester.getSize(find.byType(LiveReadChip)).height, 48);
    await tester.tap(find.text('Tomate italiano?'));
    expect(taps, 1);
  });
}
