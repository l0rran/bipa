import 'package:bipa/core/database/app_database.dart';
import 'package:bipa/core/database/database_provider.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/di/core_providers.dart';
import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/products/presentation/products_providers.dart';
import 'package:bipa/features/stock/domain/stock_movement_reason.dart';
import 'package:bipa/features/stock/presentation/home_page.dart';
import 'package:bipa/features/stock/presentation/stock_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/failing_stock_repository.dart';
import '../../../helpers/fakes.dart';
import '../../../helpers/test_database.dart';

final _now = DateTime(2026, 10, 28, 9);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('o stepper da linha avisa quando o estoque não atualiza (H11)', (tester) async {
    final AppDatabase db = createTestDatabase();
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => _now),
        idGeneratorProvider.overrideWithValue(SequentialIdGenerator()),
      ],
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      container.dispose();
      await tester.runAsync(db.close);
    });
    await tester.runAsync(() async {
      await container
          .read(productRepositoryProvider)
          .save(
            Product(id: 'leite', name: 'Leite integral', unit: MeasureUnit.liter, createdAt: _now, updatedAt: _now),
          );
      await container
          .read(stockRepositoryProvider)
          .adjust(productId: 'leite', delta: 2, reason: StockMovementReason.purchase);
    });
    // As leituras seguem no banco; só as escritas falham.
    final reads = container.read(stockRepositoryProvider);
    final failing = ProviderContainer(
      parent: container,
      overrides: [stockRepositoryProvider.overrideWithValue(FailingStockRepository(reads))],
    );
    addTearDown(failing.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: failing,
        child: MaterialApp(
          theme: BipaTheme.light,
          locale: const Locale('pt', 'BR'),
          supportedLocales: const [Locale('pt', 'BR')],
          localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
          home: const Scaffold(body: HomePage()),
        ),
      ),
    );
    await _settle(tester);

    await tester.tap(find.textContaining('Leite integral').first);
    await _settle(tester);
    await tester.tap(find.bySemanticsLabel('Uma embalagem a mais'));
    await _settle(tester);

    expect(find.text('Não deu para atualizar o estoque. Tente de novo.'), findsOneWidget);
    // O aviso some sozinho; o teste não pode terminar com o relógio dele rodando.
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('o aviso do "Usei um" com Desfazer some sozinho depois de 4 s', (tester) async {
    final AppDatabase db = createTestDatabase();
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => _now),
        idGeneratorProvider.overrideWithValue(SequentialIdGenerator()),
      ],
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      container.dispose();
      await tester.runAsync(db.close);
    });
    await tester.runAsync(() async {
      await container
          .read(productRepositoryProvider)
          .save(
            Product(id: 'leite', name: 'Leite integral', unit: MeasureUnit.liter, createdAt: _now, updatedAt: _now),
          );
      await container
          .read(stockRepositoryProvider)
          .adjust(productId: 'leite', delta: 2, reason: StockMovementReason.purchase);
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: BipaTheme.light,
          locale: const Locale('pt', 'BR'),
          supportedLocales: const [Locale('pt', 'BR')],
          localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
          home: const Scaffold(body: HomePage()),
        ),
      ),
    );
    await _settle(tester);

    await tester.drag(find.text('Leite integral').first, const Offset(-400, 0));
    await _settle(tester);

    expect(find.text('Usei um: Leite integral'), findsOneWidget);
    expect(find.text('Desfazer'), findsOneWidget);
    // No Flutter 3.47 um SnackBar com ação ficaria até alguém tocar.
    // O relógio do aviso anda por quadros: um quadro o esvazia, o seguinte
    // começa a saída e o outro a termina.
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Usei um: Leite integral'), findsNothing);
  });

  testWidgets('a busca ignora acento e a ordem das palavras, como a aba Produtos (G7)', (tester) async {
    final AppDatabase db = createTestDatabase();
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => _now),
        idGeneratorProvider.overrideWithValue(SequentialIdGenerator()),
      ],
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      container.dispose();
      await tester.runAsync(db.close);
    });
    await tester.runAsync(() async {
      for (final (id, name) in [('acucar', 'Açúcar refinado'), ('feijao', 'Feijão carioca')]) {
        await container
            .read(productRepositoryProvider)
            .save(Product(id: id, name: name, unit: MeasureUnit.kilogram, createdAt: _now, updatedAt: _now));
        await container
            .read(stockRepositoryProvider)
            .adjust(productId: id, delta: 2, reason: StockMovementReason.purchase);
      }
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: BipaTheme.light,
          locale: const Locale('pt', 'BR'),
          supportedLocales: const [Locale('pt', 'BR')],
          localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
          home: const Scaffold(body: HomePage()),
        ),
      ),
    );
    await _settle(tester);

    await tester.enterText(find.byType(TextField), 'acucar');
    await _settle(tester);
    expect(find.textContaining('Açúcar refinado'), findsWidgets);
    expect(find.textContaining('Feijão carioca'), findsNothing);

    await tester.enterText(find.byType(TextField), 'carioca feijao');
    await _settle(tester);
    expect(find.textContaining('Feijão carioca'), findsWidgets);
    expect(find.textContaining('Açúcar refinado'), findsNothing);
    // O teste não pode terminar com relógios da tela rodando.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
