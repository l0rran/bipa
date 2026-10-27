import 'package:bipa/core/widgets/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('EmptyState mostra a mensagem e dispara a ação', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmptyState(
            icon: Icons.kitchen_outlined,
            message: 'Seu estoque está vazio.',
            actionLabel: 'Ler código de barras',
            onAction: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Seu estoque está vazio.'), findsOneWidget);
    await tester.tap(find.text('Ler código de barras'));
    expect(tapped, isTrue);
  });

  testWidgets('EmptyState sem ação não mostra botão', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EmptyState(icon: Icons.search_off, message: 'Nada aqui.'),
        ),
      ),
    );

    expect(find.byType(FilledButton), findsNothing);
  });
}
