import 'dart:io';

import 'package:bipa/core/database/app_database.dart';
import 'package:bipa/core/database/database_provider.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/di/core_providers.dart';
import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/core/money/money.dart';
import 'package:bipa/features/markets/domain/market.dart';
import 'package:bipa/features/markets/presentation/markets_providers.dart';
import 'package:bipa/features/prices/domain/price_observation.dart';
import 'package:bipa/features/prices/domain/price_source.dart';
import 'package:bipa/features/prices/presentation/prices_providers.dart';
import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/products/domain/product_package.dart';
import 'package:bipa/features/products/presentation/product_detail_page.dart';
import 'package:bipa/features/products/presentation/product_photos.dart';
import 'package:bipa/features/products/presentation/products_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/test_database.dart';

final _now = DateTime(2026, 10, 28, 9);

/// O Leite Ninho bipado no Leite integral, com um preço.
Future<ProviderContainer> _pumpProduct(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(411, 2000)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final AppDatabase db = createTestDatabase();
  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      clockProvider.overrideWithValue(() => _now),
      idGeneratorProvider.overrideWithValue(SequentialIdGenerator()),
      // Sem plugin de pastas nos testes: o erro dele se repetiria por conta própria.
      productPhotosDirectoryProvider.overrideWith((ref) async => Directory.systemTemp),
    ],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    container.dispose();
    await tester.runAsync(db.close);
  });
  await tester.runAsync(() async {
    final products = container.read(productRepositoryProvider);
    for (final (id, name) in [('integral', 'Leite integral'), ('ninho', 'Leite Ninho')]) {
      await products.save(Product(id: id, name: name, unit: MeasureUnit.liter, createdAt: _now, updatedAt: _now));
    }
    await products.savePackage(
      ProductPackage(
        id: 'ninho-400',
        productId: 'integral',
        barcode: '7891000100101',
        brand: 'Ninho',
        unit: MeasureUnit.unit,
        createdAt: _now,
        updatedAt: _now,
      ),
    );
    await container
        .read(marketRepositoryProvider)
        .save(Market(id: 'm', name: 'Central', createdAt: _now, updatedAt: _now));
    await container
        .read(priceRepositoryProvider)
        .add(
          PriceObservation(
            id: 'preco',
            productId: 'integral',
            packageId: 'ninho-400',
            marketId: 'm',
            price: const Money.cents(1890),
            source: PriceSource.priceTag,
            observedAt: _now,
            createdAt: _now,
          ),
        );
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: BipaTheme.light,
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
        home: const ProductDetailPage(productId: 'integral'),
      ),
    ),
  );
  await _settle(tester);
  return container;
}

/// Deixa o banco responder (ele roda fora do relógio falso do teste).
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump(const Duration(milliseconds: 500));
}

/// Deixa o aviso passar sozinho (4 s) e sair de cena.
Future<void> _letSnackBarGo(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(seconds: 5));
  }
  await _settle(tester);
}

Future<void> _openMenuItem(WidgetTester tester, String label) async {
  await tester.tap(find.byTooltip('Mais opções'));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.tap(find.text(label).last);
  await _settle(tester);
}

void main() {
  testWidgets('"Apagar embalagem" confirma no botão neutro, apaga e desfaz', (tester) async {
    final container = await _pumpProduct(tester);
    final products = container.read(productRepositoryProvider);

    await _openMenuItem(tester, 'Apagar embalagem');
    expect(find.text('Apagar Ninho?'), findsOneWidget);
    expect(find.text('O preço dela também é apagado. O que está em casa continua no produto.'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Apagar embalagem'));
    await _settle(tester);

    expect(await tester.runAsync(() => products.findPackageById('ninho-400')), isNull);
    expect(find.text('Embalagem apagada.'), findsOneWidget);

    await tester.tap(find.text('Desfazer'));
    await _settle(tester);
    expect((await tester.runAsync(() => products.findPackageById('ninho-400')))?.productId, 'integral');
  });

  testWidgets('"Mover embalagem…" escolhe o produto, confirma e leva a embalagem', (tester) async {
    final container = await _pumpProduct(tester);
    final products = container.read(productRepositoryProvider);

    await _openMenuItem(tester, 'Mover embalagem…');
    expect(find.text('Mover para outro produto'), findsOneWidget);
    // O próprio produto não aparece na escolha.
    expect(find.widgetWithText(ListTile, 'Leite integral'), findsNothing);
    await tester.tap(find.widgetWithText(ListTile, 'Leite Ninho'));
    await _settle(tester);

    expect(find.text('Mover Ninho para Leite Ninho?'), findsOneWidget);
    expect(find.text('O preço dela vai junto.'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Mover'));
    await _settle(tester);

    expect((await tester.runAsync(() => products.findPackageById('ninho-400')))?.productId, 'ninho');
    expect(find.text('Embalagem movida para Leite Ninho.'), findsOneWidget);
  });

  /// Escolhe "Leite Ninho" no "Mover embalagem…" e confirma.
  Future<void> moveToNinho(WidgetTester tester) async {
    await _openMenuItem(tester, 'Mover embalagem…');
    await tester.tap(find.widgetWithText(ListTile, 'Leite Ninho'));
    await _settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Mover'));
    await _settle(tester);
  }

  testWidgets('o "Desfazer" da movida leva a embalagem de volta e não oferece apagar o produto', (tester) async {
    final container = await _pumpProduct(tester);
    final products = container.read(productRepositoryProvider);

    await moveToNinho(tester);
    expect(find.text('Embalagem movida para Leite Ninho.'), findsOneWidget);
    // Um botão só no aviso.
    expect(find.text('Apagar produto'), findsNothing);

    await tester.tap(find.text('Desfazer'));
    await _settle(tester);
    expect((await tester.runAsync(() => products.findPackageById('ninho-400')))?.productId, 'integral');

    await _letSnackBarGo(tester);
    expect(find.textContaining('ficou sem embalagem'), findsNothing);
    expect(find.text('Apagar produto'), findsNothing);
  });

  testWidgets('sem desfazer, o produto que ficou vazio ganha um segundo aviso com "Apagar produto"', (tester) async {
    final container = await _pumpProduct(tester);
    final products = container.read(productRepositoryProvider);

    await moveToNinho(tester);
    await _letSnackBarGo(tester);

    expect(find.text('Leite integral ficou sem embalagem, preço e estoque.'), findsOneWidget);
    expect(find.text('Desfazer'), findsNothing);
    // Não apaga sozinho; o botão abre a confirmação do apagar produto.
    expect(await tester.runAsync(() => products.findById('integral')), isNotNull);
    await tester.tap(find.text('Apagar produto'));
    await _settle(tester);
    expect(find.text('Apagar Leite integral?'), findsOneWidget);
    expect(await tester.runAsync(() => products.findById('integral')), isNotNull);
  });

  testWidgets('apagar a última embalagem também oferece "Apagar produto" depois do aviso', (tester) async {
    await _pumpProduct(tester);

    await _openMenuItem(tester, 'Apagar embalagem');
    await tester.tap(find.widgetWithText(FilledButton, 'Apagar embalagem'));
    await _settle(tester);
    expect(find.text('Embalagem apagada.'), findsOneWidget);
    expect(find.text('Apagar produto'), findsNothing);

    await _letSnackBarGo(tester);
    expect(find.text('Leite integral ficou sem embalagem, preço e estoque.'), findsOneWidget);
    expect(find.text('Apagar produto'), findsOneWidget);
  });
}
