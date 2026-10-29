import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/design_system/components/scan_tray.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) => MaterialApp(
  theme: BipaTheme.light,
  home: Scaffold(
    body: Center(
      child: SizedBox(width: 360, child: Center(child: child)),
    ),
  ),
);

void main() {
  testWidgets('com o texto tocável, o local e o Desfazer são dois botões no mesmo aviso (AB9)', (tester) async {
    final semantics = tester.ensureSemantics();
    var places = 0;
    var undos = 0;
    await tester.pumpWidget(
      _app(
        LiveReadChip(
          icon: Icons.home_outlined,
          price: '+1',
          detail: 'Leite · 1 na Geladeira',
          onDetailTap: () => places++,
          detailActionLabel: 'trocar o local',
          onTap: () => undos++,
          actionLabel: 'Desfazer',
        ),
      ),
    );

    // Um sinal só: a seta para baixo fica no texto, sem chip separado.
    expect(find.byIcon(Icons.expand_more_rounded), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    expect(tester.getSize(find.byType(LiveReadChip)).height, 48);

    expect(
      tester.getSemantics(find.bySemanticsLabel('+1, Leite · 1 na Geladeira, trocar o local')),
      matchesSemantics(label: '+1, Leite · 1 na Geladeira, trocar o local', isButton: true, hasTapAction: true),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Desfazer')),
      matchesSemantics(label: 'Desfazer', isButton: true, hasTapAction: true),
    );

    await tester.tap(find.text('Leite · 1 na Geladeira'));
    expect((places, undos), (1, 0));
    await tester.tap(find.text('Desfazer'));
    expect((places, undos), (1, 1));
    semantics.dispose();
  });

  testWidgets('sem a ação, o texto tocável é o único botão', (tester) async {
    final semantics = tester.ensureSemantics();
    var places = 0;
    await tester.pumpWidget(
      _app(
        LiveReadChip(
          icon: Icons.home_outlined,
          price: '+1',
          detail: 'Leite · 1 na Geladeira',
          onDetailTap: () => places++,
          detailActionLabel: 'trocar o local',
          // Sem onTap, o rótulo da ação não aparece.
          actionLabel: 'Desfazer',
        ),
      ),
    );

    expect(find.text('Desfazer'), findsNothing);
    await tester.tap(find.byIcon(Icons.expand_more_rounded));
    expect(places, 1);
    semantics.dispose();
  });

  testWidgets('com letra grande, o aviso com dois botões não estoura', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: _app(
          LiveReadChip(
            icon: Icons.add_rounded,
            price: '+1',
            detail: 'Leite integral Italac 1 L · 1 na Geladeira',
            onDetailTap: () {},
            detailActionLabel: 'trocar o local',
            onTap: () {},
            actionLabel: 'Desfazer',
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(LiveReadChip)).width, lessThanOrEqualTo(360));
  });
}
