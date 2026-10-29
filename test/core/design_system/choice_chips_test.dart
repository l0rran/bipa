import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/design_system/components/choice_chips.dart';
import 'package:bipa/core/design_system/components/group_label.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) => MaterialApp(
  theme: BipaTheme.light,
  home: Scaffold(body: Center(child: child)),
);

const _options = [
  ChoiceOption(value: 'despensa', label: 'Despensa', icon: Icons.shelves),
  ChoiceOption(value: 'geladeira', label: 'Geladeira', icon: Icons.kitchen_outlined),
  ChoiceOption(value: 'freezer', label: 'Freezer', icon: Icons.ac_unit_rounded),
];

void main() {
  testWidgets('os chips de escolha devolvem a opção tocada e dizem qual está marcada', (tester) async {
    final semantics = tester.ensureSemantics();
    String? chosen;
    await tester.pumpWidget(
      _app(
        ChoiceChips<String>(
          options: _options,
          selected: 'despensa',
          onSelected: (value) => chosen = value,
          semanticsLabel: 'Onde fica o Leite',
        ),
      ),
    );

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
    expect(
      tester.getSemantics(find.bySemanticsLabel('Geladeira')),
      matchesSemantics(
        label: 'Geladeira',
        isButton: true,
        hasCheckedState: true,
        isInMutuallyExclusiveGroup: true,
        hasTapAction: true,
      ),
    );
    expect(find.bySemanticsLabel('Onde fica o Leite'), findsOneWidget);

    await tester.tap(find.text('Geladeira'));
    expect(chosen, 'geladeira');
    semantics.dispose();
  });

  testWidgets('cada chip tem área de toque de 48', (tester) async {
    await tester.pumpWidget(
      _app(ChoiceChips<String>(options: _options, selected: null, onSelected: (_) {}, semanticsLabel: 'Local')),
    );

    for (final label in ['Despensa', 'Geladeira', 'Freezer']) {
      final chip = find.ancestor(of: find.text(label), matching: find.byType(GestureDetector)).last;
      expect(tester.getSize(chip).height, greaterThanOrEqualTo(48));
    }
  });

  testWidgets('na forma que quebra a linha, o escolhido troca o ícone pelo visto', (tester) async {
    await tester.pumpWidget(
      _app(
        ChoiceChips<String>(
          options: _options,
          selected: 'geladeira',
          onSelected: (_) {},
          semanticsLabel: 'Local',
          wrap: true,
        ),
      ),
    );

    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.byIcon(Icons.kitchen_outlined), findsNothing);
    expect(find.byIcon(Icons.shelves), findsOneWidget);
  });

  testWidgets('a fileira compacta mantém o ícone do escolhido', (tester) async {
    await tester.pumpWidget(
      _app(ChoiceChips<String>(options: _options, selected: 'geladeira', onSelected: (_) {}, semanticsLabel: 'Local')),
    );

    expect(find.byIcon(Icons.check_rounded), findsNothing);
    expect(find.byIcon(Icons.kitchen_outlined), findsOneWidget);
  });

  testWidgets('o nome do grupo aparece em versalete e se lê por extenso', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(const GroupLabel(title: 'Despensa', count: 4, semanticsLabel: 'Despensa, 4 produtos')),
    );

    expect(find.text('DESPENSA'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Despensa, 4 produtos')),
      matchesSemantics(label: 'Despensa, 4 produtos', isHeader: true),
    );
    semantics.dispose();
  });
}
