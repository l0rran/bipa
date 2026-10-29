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

  group('granel sem fundir variedades (G6)', () {
    testWidgets('a variedade nova mostra o produto parecido e oferece criar a variedade', (tester) async {
      final chosen = await _pumpPicker(tester, nameHint: 'BANANA NANICA KG', names: const ['Banana', 'Arroz branco']);
      final row = find.descendant(of: find.byType(ListTile), matching: find.text('Banana'));
      final create = find.text('Criar “Banana nanica”');

      // O texto lido fica à vista, para comparar com a linha que vai tocar.
      expect(find.text('Na etiqueta: BANANA NANICA KG'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Banana'), findsOneWidget);
      expect(row, findsOneWidget);
      expect(create, findsOneWidget);
      expect(tester.getTopLeft(row).dy, lessThan(tester.getTopLeft(create).dy));

      await tester.tap(create);
      await tester.pumpAndSettle();
      expect(chosen.value, isA<NewProduct>().having((n) => n.name, 'nome', 'Banana nanica'));
    });

    testWidgets('a mesma variedade acha o produto dela, sem criar outro', (tester) async {
      await _pumpPicker(tester, nameHint: 'BANANA PRATA KG', names: const ['Banana prata', 'Banana nanica']);

      expect(find.descendant(of: find.byType(ListTile), matching: find.text('Banana prata')), findsOneWidget);
      expect(find.textContaining('Criar'), findsNothing);
    });

    testWidgets('com outra variedade cadastrada, mostra o parecido e oferece criar a lida', (tester) async {
      for (final (hint, other, word, name) in [
        ('QUEIJO PRATO KG', 'Queijo mussarela', 'Queijo', 'Queijo prato'),
        ('TOMATE CEREJA KG', 'Tomate italiano', 'Tomate', 'Tomate cereja'),
        ('CARNE ACEM KG', 'Carne moída patinho', 'Carne', 'Carne acém'),
      ]) {
        await _pumpPicker(tester, nameHint: hint, names: [other]);

        expect(find.widgetWithText(TextField, word), findsOneWidget, reason: hint);
        expect(
          find.descendant(of: find.byType(ListTile), matching: find.text(other)),
          findsOneWidget,
          reason: hint,
        );
        expect(find.text('Criar “$name”'), findsOneWidget, reason: hint);

        Navigator.of(tester.element(find.byType(ProductPickerSheet))).pop();
        await tester.pumpAndSettle();
      }
    });

    testWidgets('uma palavra a mais na etiqueta mostra o produto que existe e oferece criar o lido (G9)', (
      tester,
    ) async {
      final chosen = await _pumpPicker(
        tester,
        nameHint: 'LIMAO TAITI KG',
        names: const ['Limão tahiti', 'Arroz branco'],
      );
      final row = find.descendant(of: find.byType(ListTile), matching: find.text('Limão tahiti'));
      final create = find.text('Criar “Limão taiti”');

      expect(find.text('Na etiqueta: LIMAO TAITI KG'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Limão'), findsOneWidget);
      expect(row, findsOneWidget);
      expect(create, findsOneWidget);
      expect(tester.getTopLeft(row).dy, lessThan(tester.getTopLeft(create).dy));

      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(chosen.value, isA<ExistingProduct>().having((e) => e.product.name, 'nome', 'Limão tahiti'));
    });

    testWidgets('com marca fora da lista, o queijo cadastrado aparece e "Criar" leva o recorte (G9)', (tester) async {
      final chosen = await _pumpPicker(tester, nameHint: 'MUSSARELA TIROLEZ KG', names: const ['Queijo mussarela']);

      expect(find.descendant(of: find.byType(ListTile), matching: find.text('Queijo mussarela')), findsOneWidget);
      await tester.tap(find.text('Criar “Mussarela tirolez”'));
      await tester.pumpAndSettle();
      expect(chosen.value, isA<NewProduct>().having((n) => n.name, 'nome', 'Mussarela tirolez'));
    });

    testWidgets('depois de digitar, "Criar" usa o que a pessoa digitou', (tester) async {
      final chosen = await _pumpPicker(tester, nameHint: 'BANANA NANICA KG', names: const ['Banana']);

      await tester.enterText(find.byType(TextField), 'banana da terra');
      await tester.pumpAndSettle();
      final create = find.text('Criar “banana da terra”');
      expect(create, findsOneWidget);

      await tester.tap(create);
      await tester.pumpAndSettle();
      expect(chosen.value, isA<NewProduct>().having((n) => n.name, 'nome', 'banana da terra'));
    });

    testWidgets('sem etiqueta, não há dica sob a busca', (tester) async {
      await _pumpPicker(tester, initialQuery: 'arroz');

      expect(find.textContaining('Na etiqueta'), findsNothing);
    });
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
