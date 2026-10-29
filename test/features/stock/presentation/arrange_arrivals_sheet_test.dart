import 'dart:io';

import 'package:bipa/core/database/app_database.dart';
import 'package:bipa/core/database/database_provider.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/design_system/components/choice_chips.dart';
import 'package:bipa/core/di/core_providers.dart';
import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/products/presentation/product_photos.dart';
import 'package:bipa/features/products/presentation/products_providers.dart';
import 'package:bipa/features/stock/domain/stock_location.dart';
import 'package:bipa/features/stock/domain/stock_movement_reason.dart';
import 'package:bipa/features/stock/presentation/arrange_arrivals_sheet.dart';
import 'package:bipa/features/stock/presentation/stock_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/test_database.dart';

final _now = DateTime(2026, 10, 28, 9);

Product _product(String id, String name) =>
    Product(id: id, name: name, unit: MeasureUnit.unit, createdAt: _now, updatedAt: _now);

// Na ordem em que entraram: o leite nasce na Geladeira; o arroz e o feijão,
// na Despensa (o local sugerido pela categoria).
final _leite = _product('leite', 'Leite integral 1 L');
final _arroz = _product('arroz', 'Arroz Tio João 5 kg');
final _feijao = _product('feijao', 'Feijão carioca 1 kg');

/// Põe os três em casa, como a câmera de "Comprei" faria, e abre a folha
/// com eles por cima de uma tela.
Future<ProviderContainer> _openSheet(WidgetTester tester, {double textScale = 1}) async {
  final AppDatabase db = createTestDatabase();
  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      clockProvider.overrideWithValue(() => _now),
      idGeneratorProvider.overrideWithValue(SequentialIdGenerator()),
      // Sem o path_provider no teste: nenhum produto tem foto.
      productPhotosDirectoryProvider.overrideWith((ref) async => Directory('fotos')),
    ],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    container.dispose();
    await tester.runAsync(db.close);
  });
  final arrivals = await tester.runAsync(() async {
    final products = container.read(productRepositoryProvider);
    final stock = container.read(stockRepositoryProvider);
    for (final product in [_leite, _arroz, _feijao]) {
      await products.save(product);
      await stock.adjust(productId: product.id, delta: 1, reason: StockMovementReason.purchase);
    }
    final entries = await stock.watchAll().first;
    return [
      for (final id in ['leite', 'arroz', 'feijao']) entries.firstWhere((entry) => entry.product.id == id),
    ];
  });

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: BipaTheme.light,
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(onPressed: () => showArrangeArrivalsSheet(context, arrivals!), child: const Text('abrir')),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await _settle(tester);
  return container;
}

/// Deixa o banco responder (ele roda fora do relógio falso do teste).
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump(const Duration(seconds: 1));
}

Future<({StockLocation location, double? target})> _item(
  WidgetTester tester,
  ProviderContainer container,
  String id,
) async {
  final item = await tester.runAsync(() => container.read(stockRepositoryProvider).findByProduct(id));
  return (location: item!.location, target: item.targetQuantity);
}

void main() {
  testWidgets('a folha agrupa o que entrou pelo local em que nasceu, com o primeiro aberto', (tester) async {
    final semantics = tester.ensureSemantics();
    await _openSheet(tester);

    expect(find.bySemanticsLabel('Arrumar o que entrou, 3 produtos'), findsOneWidget);
    expect(find.text('DESPENSA'), findsOneWidget);
    expect(find.text('GELADEIRA'), findsOneWidget);
    expect(find.bySemanticsLabel('Despensa, 2 produtos'), findsOneWidget);
    expect(find.bySemanticsLabel('Geladeira, 1 produto'), findsOneWidget);
    // A Despensa vem antes, na ordem dos locais; dentro dela, a ordem em que entraram.
    final top = [
      for (final name in ['DESPENSA', 'Arroz Tio João 5 kg', 'Feijão carioca 1 kg', 'GELADEIRA', 'Leite integral 1 L'])
        tester.getTopLeft(find.text(name)).dy,
    ];
    expect(top, orderedEquals([...top]..sort()));

    // Só o primeiro item da folha está aberto, com os locais e o "ter sempre".
    expect(find.byType(ChoiceChips<StockLocation>), findsOneWidget);
    expect(find.bySemanticsLabel('Onde fica Arroz Tio João 5 kg?'), findsOneWidget);
    expect(find.text('Ter sempre'), findsOneWidget);
    expect(find.bySemanticsLabel('ter sempre: não definido'), findsOneWidget);
    expect(find.text('Pronto'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('cada toque salva na hora, e a linha não pula de grupo', (tester) async {
    final container = await _openSheet(tester);

    await tester.tap(find.text('Freezer'));
    await _settle(tester);
    expect((await _item(tester, container, 'arroz')).location, StockLocation.freezer);
    // Continua sob "Despensa", agora com o Freezer marcado.
    expect(find.text('FREEZER'), findsNothing);
    final freezer = tester.widget<ChoiceChips<StockLocation>>(find.byType(ChoiceChips<StockLocation>));
    expect(freezer.selected, StockLocation.freezer);

    await tester.tap(find.bySemanticsLabel('Ter sempre mais'));
    await _settle(tester);
    await tester.tap(find.bySemanticsLabel('Ter sempre mais'));
    await _settle(tester);
    expect((await _item(tester, container, 'arroz')).target, 2);

    await tester.tap(find.bySemanticsLabel('Ter sempre menos'));
    await _settle(tester);
    expect((await _item(tester, container, 'arroz')).target, 1);
  });

  testWidgets('tocar em outro item abre o dele e fecha o anterior', (tester) async {
    await _openSheet(tester);

    await tester.tap(find.text('Leite integral 1 L'));
    await _settle(tester);

    expect(find.byType(ChoiceChips<StockLocation>), findsOneWidget);
    expect(find.bySemanticsLabel('Onde fica Leite integral 1 L?'), findsOneWidget);
    final chips = tester.widget<ChoiceChips<StockLocation>>(find.byType(ChoiceChips<StockLocation>));
    expect(chips.selected, StockLocation.fridge);

    // Tocar de novo fecha.
    await tester.tap(find.text('Leite integral 1 L'));
    await _settle(tester);
    expect(find.byType(ChoiceChips<StockLocation>), findsNothing);
  });

  testWidgets('"Pronto" fecha a folha sem mudar nada', (tester) async {
    final container = await _openSheet(tester);

    await tester.tap(find.text('Pronto'));
    await _settle(tester);

    expect(find.text('Arrumar o que entrou'), findsNothing);
    expect(await _item(tester, container, 'arroz'), (location: StockLocation.pantry, target: null));
    expect(await _item(tester, container, 'leite'), (location: StockLocation.fridge, target: null));
  });

  testWidgets('com letra grande, a folha não estoura e o "Pronto" continua à vista', (tester) async {
    await _openSheet(tester, textScale: 2);

    expect(tester.takeException(), isNull);
    expect(find.text('Pronto'), findsOneWidget);
    expect(
      tester.getBottomLeft(find.text('Pronto')).dy,
      lessThanOrEqualTo(tester.view.physicalSize.height / tester.view.devicePixelRatio),
    );
  });
}
