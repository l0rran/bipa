import 'package:bipa/core/database/app_database.dart';
import 'package:bipa/core/database/database_provider.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/di/core_providers.dart';
import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/products/presentation/products_providers.dart';
import 'package:bipa/features/stock/data/drift_stock_repository.dart';
import 'package:bipa/features/stock/domain/stock_location.dart';
import 'package:bipa/features/stock/presentation/stock_item_sheet.dart';
import 'package:bipa/features/stock/presentation/stock_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/failing_stock_repository.dart';
import '../../../helpers/fakes.dart';
import '../../../helpers/test_database.dart';

final _now = DateTime(2026, 10, 28, 9);

Product _product(String id, String name) =>
    Product(id: id, name: name, unit: MeasureUnit.unit, createdAt: _now, updatedAt: _now);

/// Abre a folha do item de [product] como o app abre, por cima de uma tela.
Future<ProviderContainer> _openSheet(WidgetTester tester, Product product, {bool failingWrites = false}) async {
  final AppDatabase db = createTestDatabase();
  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      clockProvider.overrideWithValue(() => _now),
      idGeneratorProvider.overrideWithValue(SequentialIdGenerator()),
      // As leituras seguem no banco; só as escritas falham.
      if (failingWrites)
        stockRepositoryProvider.overrideWithValue(
          FailingStockRepository(DriftStockRepository(db, ids: SequentialIdGenerator(), clock: () => _now)),
        ),
    ],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    container.dispose();
    await tester.runAsync(db.close);
  });
  await tester.runAsync(() => container.read(productRepositoryProvider).save(product));

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: BipaTheme.light,
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(onPressed: () => showStockItemSheet(context, product), child: const Text('abrir')),
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

/// O local marcado na folha, ou `null` se nenhum estiver.
StockLocation? _selectedLocation(WidgetTester tester) {
  final chips = tester.widgetList<ChoiceChip>(find.byType(ChoiceChip));
  final selected = [
    for (final (index, chip) in chips.indexed)
      if (chip.selected) StockLocation.values[index],
  ];
  return selected.singleOrNull;
}

void main() {
  group('local marcado enquanto o item não existe', () {
    testWidgets('leite nasce marcado na Geladeira', (tester) async {
      await _openSheet(tester, _product('leite', 'Leite integral 1 L'));
      expect(_selectedLocation(tester), StockLocation.fridge);
    });

    testWidgets('lasanha congelada nasce marcada no Freezer', (tester) async {
      await _openSheet(tester, _product('lasanha', 'Lasanha congelada'));
      expect(_selectedLocation(tester), StockLocation.freezer);
    });

    testWidgets('sem categoria conhecida, fica a Despensa', (tester) async {
      await _openSheet(tester, _product('pilhas', 'Pilhas AA'));
      expect(_selectedLocation(tester), StockLocation.pantry);
    });

    testWidgets('o primeiro "+" não troca o local marcado', (tester) async {
      final container = await _openSheet(tester, _product('leite', 'Leite integral 1 L'));
      await tester.tap(find.bySemanticsLabel('Uma embalagem a mais'));
      await _settle(tester);
      expect(_selectedLocation(tester), StockLocation.fridge);
      final item = await tester.runAsync(() => container.read(stockRepositoryProvider).findByProduct('leite'));
      expect(item?.location, StockLocation.fridge);
    });

    testWidgets('depois de tirar de casa, marca o local que a pessoa tinha escolhido (ADR 0021)', (tester) async {
      final container = await _openSheet(tester, _product('leite', 'Leite integral 1 L'));
      await tester.tap(find.widgetWithText(ChoiceChip, 'Despensa'));
      await _settle(tester);
      await tester.runAsync(() => container.read(stockRepositoryProvider).remove('leite'));
      await _settle(tester);

      expect(_selectedLocation(tester), StockLocation.pantry);
      await tester.tap(find.bySemanticsLabel('Uma embalagem a mais'));
      await _settle(tester);
      expect(_selectedLocation(tester), StockLocation.pantry);
      final item = await tester.runAsync(() => container.read(stockRepositoryProvider).findByProduct('leite'));
      expect(item?.location, StockLocation.pantry);
    });
  });

  group('falhas do banco avisam (H11)', () {
    const failed = 'Não deu para atualizar o estoque. Tente de novo.';

    testWidgets('o stepper de "Em casa" mostra o aviso', (tester) async {
      await _openSheet(tester, _product('leite', 'Leite integral 1 L'), failingWrites: true);
      await tester.tap(find.bySemanticsLabel('Uma embalagem a mais'));
      await _settle(tester);
      expect(find.text(failed), findsOneWidget);
    });

    testWidgets('o stepper do "ter sempre" mostra o aviso', (tester) async {
      await _openSheet(tester, _product('leite', 'Leite integral 1 L'), failingWrites: true);
      await tester.tap(find.bySemanticsLabel('Ter sempre mais'));
      await _settle(tester);
      expect(find.text(failed), findsOneWidget);
    });

    testWidgets('trocar o local mostra o aviso', (tester) async {
      await _openSheet(tester, _product('leite', 'Leite integral 1 L'), failingWrites: true);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Despensa'));
      await _settle(tester);
      expect(find.text(failed), findsOneWidget);
    });

    testWidgets('sem falha, nenhum aviso aparece', (tester) async {
      await _openSheet(tester, _product('leite', 'Leite integral 1 L'));
      await tester.tap(find.bySemanticsLabel('Uma embalagem a mais'));
      await _settle(tester);
      expect(find.text(failed), findsNothing);
    });
  });
}
