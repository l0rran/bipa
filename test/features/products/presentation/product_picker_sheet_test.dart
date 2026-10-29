import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/products/presentation/product_picker_sheet.dart';
import 'package:bipa/features/products/presentation/products_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fakes.dart';

final _now = DateTime(2026, 10, 28, 9);

/// Abre a escolha de produto e devolve o que a pessoa escolheu.
Future<ValueNotifier<ProductChoice?>> _pumpPicker(
  WidgetTester tester, {
  String initialQuery = '',
  String? nameHint,
  bool allowCreate = true,
  List<String> names = const ['Feijão carioca', 'Açúcar refinado', 'Arroz branco', 'Arroz integral'],
}) async {
  final products = InMemoryProductRepository();
  for (final (i, name) in names.indexed) {
    products.products['p$i'] = Product(
      id: 'p$i',
      name: name,
      unit: MeasureUnit.kilogram,
      createdAt: _now,
      updatedAt: _now,
    );
  }
  final chosen = ValueNotifier<ProductChoice?>(null);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [productRepositoryProvider.overrideWithValue(products)],
      child: MaterialApp(
        theme: BipaTheme.light,
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
        home: Consumer(
          builder: (context, ref, _) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async => chosen.value = nameHint == null
                    ? await pickProduct(context, initialQuery: initialQuery, allowCreate: allowCreate)
                    : await pickProductForLabel(context, ref, nameHint: nameHint, allowCreate: allowCreate),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
  return chosen;
}

void main() {
  testWidgets('o texto da etiqueta acha o produto com acento e não oferece cadastrar outro', (tester) async {
    final chosen = await _pumpPicker(tester, initialQuery: 'FEIJAO CARIOCA');

    expect(find.text('Feijão carioca'), findsOneWidget);
    expect(find.textContaining('Criar'), findsNothing);

    await tester.tap(find.text('Feijão carioca'));
    await tester.pumpAndSettle();
    expect(chosen.value, isA<ExistingProduct>().having((e) => e.product.name, 'nome', 'Feijão carioca'));
  });

  testWidgets('a etiqueta crua, com marca e tamanho, abre recortada e acha o produto (G4)', (tester) async {
    final chosen = await _pumpPicker(tester, nameHint: 'FEIJAO CARIOCA CAMIL 1KG');
    final row = find.descendant(of: find.byType(ListTile), matching: find.text('Feijão carioca'));

    expect(find.widgetWithText(TextField, 'Feijão carioca'), findsOneWidget);
    expect(row, findsOneWidget);
    expect(find.textContaining('Criar'), findsNothing);

    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(chosen.value, isA<ExistingProduct>().having((e) => e.product.name, 'nome', 'Feijão carioca'));
  });

  testWidgets('sem o produto, a etiqueta recortada vira o nome do novo (G4)', (tester) async {
    await _pumpPicker(tester, nameHint: 'MACARRAO PARAFUSO RENATA 500G');

    expect(find.widgetWithText(TextField, 'Macarrão parafuso'), findsOneWidget);
    expect(find.text('Criar “Macarrão parafuso”'), findsOneWidget);
  });

  testWidgets('digitar sem acento e em outra ordem também acha', (tester) async {
    await _pumpPicker(tester);

    await tester.enterText(find.byType(TextField), 'acucar');
    await tester.pumpAndSettle();
    expect(find.text('Açúcar refinado'), findsOneWidget);
    expect(find.text('Feijão carioca'), findsNothing);

    await tester.enterText(find.byType(TextField), 'carioca feijao');
    await tester.pumpAndSettle();
    expect(find.text('Feijão carioca'), findsOneWidget);
    expect(find.textContaining('Criar'), findsNothing);
  });

  testWidgets('com resultados parecidos, "Criar" fica abaixo deles', (tester) async {
    final chosen = await _pumpPicker(tester);

    await tester.enterText(find.byType(TextField), 'arroz');
    await tester.pumpAndSettle();

    final create = find.text('Criar “arroz”');
    expect(create, findsOneWidget);
    final below = tester.getTopLeft(create).dy;
    expect(tester.getTopLeft(find.text('Arroz branco')).dy, lessThan(below));
    expect(tester.getTopLeft(find.text('Arroz integral')).dy, lessThan(below));

    await tester.tap(create);
    await tester.pumpAndSettle();
    expect(chosen.value, isA<NewProduct>().having((n) => n.name, 'nome', 'arroz'));
  });

  testWidgets('sem nenhum parecido, "Criar" é a única linha', (tester) async {
    await _pumpPicker(tester);

    await tester.enterText(find.byType(TextField), 'tapioca');
    await tester.pumpAndSettle();

    expect(find.text('Criar “tapioca”'), findsOneWidget);
    expect(find.byType(ListTile), findsOneWidget);
  });

  testWidgets('sem permissão para criar, só os que existem', (tester) async {
    await _pumpPicker(tester, allowCreate: false, initialQuery: 'AÇUCAR');

    expect(find.text('Açúcar refinado'), findsOneWidget);
    expect(find.textContaining('Criar'), findsNothing);

    await tester.enterText(find.byType(TextField), 'tapioca');
    await tester.pumpAndSettle();
    expect(find.text('Nenhum produto com esse nome.'), findsOneWidget);
  });
}
