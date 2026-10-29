import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/design_system/components/scan_tray.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child, {double width = 360}) => MaterialApp(
  theme: BipaTheme.light,
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: width,
        child: Center(child: child),
      ),
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

  group('com o nome em cima (AB12)', () {
    LiveReadChip chip({VoidCallback? onPlace, VoidCallback? onUndo}) => LiveReadChip(
      icon: Icons.home_outlined,
      price: '+1',
      title: 'Leite condensado Moça 395 g com um nome que não cabe numa linha só',
      detail: '1 na Despensa',
      onDetailTap: onPlace ?? () {},
      detailActionLabel: 'trocar o local',
      onTap: onUndo ?? () {},
      actionLabel: 'Desfazer',
    );

    RenderParagraph paragraph(WidgetTester tester, String text) =>
        tester.renderObject<RenderParagraph>(find.text(text, findRichText: true));

    testWidgets('o nome corta na linha dele, e o local, embaixo, não corta', (tester) async {
      final semantics = tester.ensureSemantics();
      var places = 0;
      var undos = 0;
      // Na fonte dos testes, cada letra tem 1 em de largura: a 480, o local cabe numa linha.
      await tester.pumpWidget(_app(chip(onPlace: () => places++, onUndo: () => undos++), width: 480));

      final name = tester.getRect(find.textContaining('Leite condensado'));
      final place = tester.getRect(find.text('1 na Despensa'));
      expect(place.top, greaterThanOrEqualTo(name.bottom));
      expect(
        paragraph(tester, 'Leite condensado Moça 395 g com um nome que não cabe numa linha só').didExceedMaxLines,
        isTrue,
      );
      expect(paragraph(tester, '1 na Despensa').didExceedMaxLines, isFalse);
      // A seta fica com o local, que é o que ela troca.
      expect(tester.getCenter(find.byIcon(Icons.expand_more_rounded)).dy, closeTo(place.center.dy, 2));
      expect(tester.getSize(find.byType(LiveReadChip)).height, 56);

      const label =
          '+1, Leite condensado Moça 395 g com um nome que não cabe numa linha só, 1 na Despensa, trocar o local';
      expect(
        tester.getSemantics(find.bySemanticsLabel(label)),
        matchesSemantics(label: label, isButton: true, hasTapAction: true),
      );

      await tester.tap(find.text('1 na Despensa'));
      expect((places, undos), (1, 0));
      await tester.tap(find.text('Desfazer'));
      expect((places, undos), (1, 1));
      semantics.dispose();
    });

    testWidgets('com letra grande, o aviso cresce, e o local continua inteiro', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: _app(chip()),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(LiveReadChip)).width, lessThanOrEqualTo(360));
      expect(tester.getSize(find.byType(LiveReadChip)).height, greaterThan(56));
      expect(paragraph(tester, '1 na Despensa').didExceedMaxLines, isFalse);
    });
  });

  testWidgets('o chip do modo diz o modo, sem ser um botão', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(const CameraModeChip(icon: Icons.home_outlined, label: 'Dar baixa em casa')));

    expect(find.text('Dar baixa em casa'), findsOneWidget);
    expect(find.bySemanticsLabel('Dar baixa em casa'), findsOneWidget);
    expect(find.byIcon(Icons.expand_more_rounded), findsNothing);
    expect(find.byType(InkWell), findsNothing);
    semantics.dispose();
  });
}
