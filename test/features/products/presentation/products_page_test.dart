import 'package:bipa/core/database/app_database.dart';
import 'package:bipa/core/database/database_provider.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/di/core_providers.dart';
import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/core/money/money.dart';
import 'package:bipa/core/navigation/routes.dart';
import 'package:bipa/features/markets/domain/market.dart';
import 'package:bipa/features/markets/presentation/markets_providers.dart';
import 'package:bipa/features/prices/domain/price_observation.dart';
import 'package:bipa/features/prices/domain/price_source.dart';
import 'package:bipa/features/prices/presentation/prices_providers.dart';
import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/products/domain/product_package.dart';
import 'package:bipa/features/products/presentation/products_page.dart';
import 'package:bipa/features/products/presentation/products_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/test_database.dart';

final _now = DateTime(2026, 10, 28, 9);

/// Monta a aba Produtos num roteador que só anota para onde a navegação foi.
Future<({ProviderContainer container, GoRouter router})> _pump(
  WidgetTester tester, {
  bool seeded = true,
  double textScale = 1,
}) async {
  tester.view
    ..physicalSize = const Size(411, 1600)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final AppDatabase db = createTestDatabase();
  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      clockProvider.overrideWithValue(() => _now),
      idGeneratorProvider.overrideWithValue(SequentialIdGenerator()),
    ],
  );
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const ProductsPage()),
      GoRoute(
        path: '/produto/novo',
        builder: (_, _) => const Scaffold(body: Text('formulário')),
      ),
      GoRoute(
        path: '/produto/:id',
        builder: (_, state) => Scaffold(body: Text('produto ${state.pathParameters['id']}')),
      ),
      GoRoute(
        path: Routes.camera,
        builder: (_, state) => Scaffold(body: Text('câmera ${state.uri.queryParameters['modo']}')),
      ),
    ],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    router.dispose();
    container.dispose();
    await tester.runAsync(db.close);
  });
  if (seeded) await tester.runAsync(() => _seed(container));
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        theme: BipaTheme.light,
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
  await _settle(tester);
  return (container: container, router: router);
}

/// Açúcar (uma embalagem), Arroz (duas), Sabão (uma, sem preço) e Tomate (a
/// granel).
Future<void> _seed(ProviderContainer container) async {
  final products = container.read(productRepositoryProvider);
  Product product(String id, String name, MeasureUnit unit) =>
      Product(id: id, name: name, unit: unit, createdAt: _now, updatedAt: _now);
  ProductPackage package(String id, String productId, String brand, double size, MeasureUnit unit) => ProductPackage(
    id: id,
    productId: productId,
    brand: brand,
    size: size,
    unit: unit,
    createdAt: _now,
    updatedAt: _now,
  );
  await products.save(product('acucar', 'Açúcar refinado', MeasureUnit.kilogram));
  await products.save(product('arroz', 'Arroz branco', MeasureUnit.kilogram));
  await products.save(product('sabao', 'Sabão em pó', MeasureUnit.kilogram));
  await products.save(product('tomate', 'Tomate italiano', MeasureUnit.kilogram));
  await products.savePackage(package('uniao', 'acucar', 'União', 1, MeasureUnit.kilogram));
  await products.savePackage(package('tio-joao', 'arroz', 'Tio João', 5, MeasureUnit.kilogram));
  await products.savePackage(package('camil', 'arroz', 'Camil', 10, MeasureUnit.kilogram));
  await products.savePackage(package('omo', 'sabao', 'Omo', 1.6, MeasureUnit.kilogram));

  await container
      .read(marketRepositoryProvider)
      .save(Market(id: 'm', name: 'Central', createdAt: _now, updatedAt: _now));
  var seq = 0;
  Future<void> price(String productId, String? packageId, int cents) => container
      .read(priceRepositoryProvider)
      .add(
        PriceObservation(
          id: 'o${seq++}',
          productId: productId,
          packageId: packageId,
          marketId: 'm',
          price: Money.cents(cents),
          source: PriceSource.priceTag,
          observedAt: _now,
          createdAt: _now,
        ),
      );
  await price('acucar', 'uniao', 459);
  await price('arroz', 'tio-joao', 2790);
  await price('arroz', 'camil', 4990);
  await price('tomate', null, 899);
}

/// Deixa o banco responder (ele roda fora do relógio falso do teste).
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump(const Duration(milliseconds: 500));
}

/// O valor como o app o escreve (com o espaço sem quebra depois do R$).
String _money(int cents) => Money.cents(cents).format();

void main() {
  testWidgets('lista os produtos em ordem, com a embalagem ou quantas são, e o preço', (tester) async {
    await _pump(tester);

    expect(find.text('Produtos'), findsOneWidget);
    expect(find.text('Buscar produto'), findsOneWidget);

    // Uma embalagem: marca, tamanho e o preço dela.
    expect(find.text('União · 1 kg'), findsOneWidget);
    expect(find.text(_money(459)), findsOneWidget);
    // Várias: a contagem e o preço por kg da mais barata (49,90 / 10 kg).
    expect(find.text('2 embalagens'), findsOneWidget);
    expect(find.text(_money(499)), findsOneWidget);
    // A granel: o preço por kg.
    expect(find.text('a granel'), findsOneWidget);
    expect(find.text(_money(899)), findsOneWidget);
    // "o kg" aparece nos dois preços por unidade, e só neles.
    expect(find.text('o kg'), findsNWidgets(2));
    // Sem preço, a linha não mostra preço nem texto no lugar dele.
    expect(find.text('Omo · 1,6 kg'), findsOneWidget);
    expect(find.textContaining(Money.symbol), findsNWidgets(3));
    expect(find.text('sem preço'), findsNothing);

    // Ordem alfabética, e "Cadastrar produto" fecha a lista.
    final titles = ['Açúcar refinado', 'Arroz branco', 'Sabão em pó', 'Tomate italiano', 'Cadastrar produto'];
    final tops = [for (final title in titles) tester.getTopLeft(find.text(title)).dy];
    expect([...tops]..sort(), tops);
  });

  testWidgets('não há chips de filtro nem botões na barra: só a busca e as linhas', (tester) async {
    await _pump(tester);

    expect(find.byType(AppBar), findsNothing);
    expect(find.byType(SearchBar), findsNothing);
    expect(find.byType(FilterChip), findsNothing);
    expect(find.byType(ChoiceChip), findsNothing);
  });

  testWidgets('tocar no produto abre o produto', (tester) async {
    final (:container, :router) = await _pump(tester);

    await tester.tap(find.text('Arroz branco'));
    await _settle(tester);

    expect(router.state.uri.path, '/produto/arroz');
    expect(find.text('produto arroz'), findsOneWidget);
    expect(container.read(productSearchQueryProvider), isEmpty);
  });

  testWidgets('o bipar da busca abre a câmera em "Código"', (tester) async {
    final (:container, :router) = await _pump(tester);

    await tester.tap(find.byTooltip('Bipar um produto'));
    await _settle(tester);

    expect(router.state.uri.path, Routes.camera);
    expect(router.state.uri.queryParameters['modo'], 'codigo');
  });

  testWidgets('"Cadastrar produto" abre o formulário', (tester) async {
    final (:container, :router) = await _pump(tester);

    await tester.tap(find.text('Cadastrar produto'));
    await _settle(tester);

    expect(router.state.uri.path, Routes.newProduct);
  });

  testWidgets('a busca filtra por nome e por marca, sem tirar o campo da tela', (tester) async {
    await _pump(tester);

    await tester.enterText(find.byType(TextField), 'arroz');
    await _settle(tester);
    expect(find.text('Arroz branco'), findsOneWidget);
    expect(find.text('Açúcar refinado'), findsNothing);
    expect(find.text('Cadastrar produto'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    // A marca de uma das embalagens também acha o produto.
    await tester.enterText(find.byType(TextField), 'omo');
    await _settle(tester);
    expect(find.text('Sabão em pó'), findsOneWidget);
    expect(find.text('Arroz branco'), findsNothing);
  });

  testWidgets('busca sem resultado diz isso e deixa o cadastro à mão', (tester) async {
    await _pump(tester);

    await tester.enterText(find.byType(TextField), 'zzzz');
    await _settle(tester);

    expect(find.text('Nenhum produto encontrado.'), findsOneWidget);
    expect(find.text('Cadastrar produto'), findsOneWidget);
  });

  testWidgets('sem produto nenhum, a busca com o bipar fica e o convite vem embaixo', (tester) async {
    final (:container, :router) = await _pump(tester, seeded: false);

    expect(find.text('Produtos'), findsOneWidget);
    expect(find.byTooltip('Bipar um produto'), findsOneWidget);
    expect(find.textContaining('Nenhum produto ainda.'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Cadastrar produto'));
    await _settle(tester);
    expect(router.state.uri.path, Routes.newProduct);
  });

  testWidgets('com letra a 200%, a lista cabe sem estourar', (tester) async {
    await _pump(tester, textScale: 2);

    expect(find.text('Arroz branco'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
