import 'package:bipa/core/database/app_database.dart';
import 'package:bipa/core/database/database_provider.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/design_system/components/bipa_search_bar.dart';
import 'package:bipa/core/design_system/components/camera_mode_switch.dart';
import 'package:bipa/core/design_system/components/dropdown_chip.dart';
import 'package:bipa/core/design_system/components/error_line.dart';
import 'package:bipa/core/design_system/components/list_cost_compare.dart';
import 'package:bipa/core/design_system/components/place_filter.dart';
import 'package:bipa/core/design_system/components/price_rows.dart';
import 'package:bipa/core/design_system/components/product_card.dart';
import 'package:bipa/core/design_system/components/quantity_stepper.dart';
import 'package:bipa/core/design_system/components/scan_tray.dart';
import 'package:bipa/core/design_system/components/section_header.dart';
import 'package:bipa/core/design_system/components/shopping_list.dart';
import 'package:bipa/core/design_system/components/stock_gauge.dart';
import 'package:bipa/core/design_system/components/stock_list.dart';
import 'package:bipa/core/di/core_providers.dart';
import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/core/location/geo_point.dart';
import 'package:bipa/core/location/location_service.dart';
import 'package:bipa/core/money/money.dart';
import 'package:bipa/core/permissions/permission_access.dart';
import 'package:bipa/features/markets/domain/market.dart';
import 'package:bipa/features/markets/presentation/market_page.dart';
import 'package:bipa/features/markets/presentation/markets_page.dart';
import 'package:bipa/features/markets/presentation/markets_providers.dart';
import 'package:bipa/features/prices/domain/price_observation.dart';
import 'package:bipa/features/prices/domain/price_source.dart';
import 'package:bipa/features/prices/presentation/prices_providers.dart';
import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/products/domain/product_package.dart';
import 'package:bipa/features/products/presentation/product_detail_page.dart';
import 'package:bipa/features/products/presentation/products_page.dart';
import 'package:bipa/features/products/presentation/products_providers.dart';
import 'package:bipa/features/shopping_list/domain/trip_review.dart';
import 'package:bipa/features/shopping_list/presentation/shopping_list_page.dart';
import 'package:bipa/features/shopping_list/presentation/shopping_list_providers.dart';
import 'package:bipa/features/shopping_list/presentation/trip_review_sheet.dart';
import 'package:bipa/features/stock/domain/stock_location.dart';
import 'package:bipa/features/stock/domain/stock_movement_reason.dart';
import 'package:bipa/features/stock/presentation/home_page.dart';
import 'package:bipa/features/stock/presentation/stock_item_sheet.dart';
import 'package:bipa/features/stock/presentation/stock_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';
import '../helpers/test_database.dart';

/// Letra a 200% (WCAG 1.4.4, o máximo do Android): nenhuma tela principal
/// pode cortar texto. O Flutter reporta o `RenderFlex overflow` como erro, e o
/// teste falha com ele, dizendo qual linha estourou.
///
/// A barra de navegação (`ScanNavBar`) fica de fora: as telas são montadas
/// sem o `HomeShell`, que a desenha.
const _scale = 2.0;

/// Um celular comum, em pixels lógicos de largura. A altura é grande de
/// propósito: o que está abaixo da dobra só é medido quando entra na tela, e
/// o teste precisa medir tudo.
const _phone = Size(411, 4000);

final _now = DateTime(2026, 10, 28, 9);

const _cafe = 'cafe';
const _leite = 'leite';
const _detergente = 'detergente';
const _papel = 'papel';
const _longMarket = 'm-longo';
const _shortMarket = 'm-curto';

/// Posição fixa: a tela de Mercados ordena por distância sem pedir o GPS.
final class _FixedLocation implements LocationService {
  @override
  Future<PermissionAccess> access() async => PermissionAccess.granted;

  @override
  Future<PermissionAccess> requestAccess() async => PermissionAccess.granted;

  @override
  Future<LocationResult> currentLocation({bool request = true}) async =>
      const LocationFound(GeoPoint(latitude: -23.5614, longitude: -46.6559));
}

/// Dados que enchem as telas: nomes compridos, falta de estoque, lista com
/// itens marcados, preços de dois mercados.
Future<void> _seed(ProviderContainer container) async {
  final products = container.read(productRepositoryProvider);
  Product product(String id, String name, MeasureUnit unit) =>
      Product(id: id, name: name, unit: unit, createdAt: _now, updatedAt: _now);
  await products.save(product(_cafe, 'Café torrado e moído extraforte tradicional', MeasureUnit.gram));
  await products.save(product(_leite, 'Leite integral', MeasureUnit.liter));
  await products.save(product(_detergente, 'Detergente líquido neutro para louças', MeasureUnit.milliliter));
  await products.save(product(_papel, 'Papel higiênico folha dupla neutro', MeasureUnit.unit));
  ProductPackage package(String id, String productId, MeasureUnit unit, double size, String brand) => ProductPackage(
    id: id,
    productId: productId,
    unit: unit,
    size: size,
    brand: brand,
    barcode: '789$id',
    createdAt: _now,
    updatedAt: _now,
  );
  await products.savePackage(package('p-cafe', _cafe, MeasureUnit.gram, 500, 'Pilão'));
  await products.savePackage(package('p-cafe2', _cafe, MeasureUnit.gram, 250, 'Melitta'));
  await products.savePackage(package('p-leite', _leite, MeasureUnit.liter, 1, 'Piracanjuba'));
  await products.savePackage(package('p-det', _detergente, MeasureUnit.milliliter, 500, 'Ypê'));

  final stock = container.read(stockRepositoryProvider);
  await stock.adjust(productId: _cafe, delta: 1, reason: StockMovementReason.purchase, packageId: 'p-cafe');
  await stock.adjust(productId: _leite, delta: 12, reason: StockMovementReason.purchase, packageId: 'p-leite');
  await stock.adjust(productId: _detergente, delta: 2, reason: StockMovementReason.purchase, packageId: 'p-det');
  await stock.adjust(productId: _papel, delta: 0, reason: StockMovementReason.adjustment);
  await stock.setTargetQuantity(_cafe, 3);
  await stock.setTargetQuantity(_leite, 4);
  await stock.setTargetQuantity(_papel, 2);
  await stock.setLocation(_leite, StockLocation.fridge);
  await stock.setLocation(_detergente, StockLocation.cleaning);
  await stock.setLocation(_papel, StockLocation.bathroom);

  final markets = container.read(marketRepositoryProvider);
  await markets.save(
    Market(
      id: _longMarket,
      name: 'Supermercado Pão de Açúcar da Avenida Paulista',
      address: 'Avenida Paulista, 2073, Consolação, São Paulo',
      location: const GeoPoint(latitude: -23.5565, longitude: -46.6620),
      createdAt: _now,
      updatedAt: _now,
    ),
  );
  await markets.save(
    Market(
      id: _shortMarket,
      name: 'Atacadão',
      location: const GeoPoint(latitude: -23.60, longitude: -46.70),
      createdAt: _now,
      updatedAt: _now,
    ),
  );

  final prices = container.read(priceRepositoryProvider);
  var n = 0;
  PriceObservation price(String market, String productId, String packageId, int cents, int daysAgo) {
    final at = _now.subtract(Duration(days: daysAgo));
    return PriceObservation(
      id: 'o${++n}',
      productId: productId,
      packageId: packageId,
      marketId: market,
      price: Money.cents(cents),
      source: PriceSource.priceTag,
      observedAt: at,
      createdAt: at,
    );
  }

  await prices.addAll([
    price(_longMarket, _cafe, 'p-cafe', 2890, 2),
    price(_longMarket, _cafe, 'p-cafe', 3190, 40),
    price(_longMarket, _leite, 'p-leite', 599, 2),
    price(_longMarket, _detergente, 'p-det', 249, 12),
    price(_shortMarket, _cafe, 'p-cafe', 2690, 5),
    price(_shortMarket, _cafe, 'p-cafe2', 1590, 5),
    price(_shortMarket, _leite, 'p-leite', 549, 5),
  ]);

  final list = container.read(shoppingListRepositoryProvider);
  await list.addProduct(productId: _cafe, name: 'Café torrado e moído extraforte tradicional', quantity: 2);
  await list.addProduct(productId: _leite, name: 'Leite integral', quantity: 12);
  await list.addProduct(productId: _detergente, name: 'Detergente líquido neutro para louças');
  await list.addCustom('Pão francês quentinho da padaria', quantity: 6);
  await list.addCustom('Presente');
  await list.checkProduct(_detergente);
}

/// A compra em andamento no mercado de nome comprido, com dois itens no
/// carrinho: um com preço lido e outro estimado.
Future<void> _startTrip(ProviderContainer container) async {
  final trip = await container.read(shoppingTripRepositoryProvider).start(marketId: _longMarket);
  final cart = container.read(cartRepositoryProvider);
  await cart.addProduct(trip.id, _cafe, packageId: 'p-cafe', price: const Money.cents(2890));
  await cart.addProduct(trip.id, _leite, packageId: 'p-leite', price: const Money.cents(599), estimated: true);
}

Widget _app(Widget home, {double scale = _scale}) => MaterialApp(
  theme: BipaTheme.light,
  locale: const Locale('pt', 'BR'),
  supportedLocales: const [Locale('pt', 'BR')],
  localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: home,
);

void _usePhone(WidgetTester tester) {
  tester.view
    ..physicalSize = _phone
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Monta [screen] como o app a monta (tema, textos em português, banco em
/// memória com os dados de [_seed]), com a letra a 200%, e espera os streams
/// do banco responderem.
Future<ProviderContainer> _pumpScreen(
  WidgetTester tester,
  Widget screen, {
  Future<void> Function(ProviderContainer container)? prepare,
}) async {
  _usePhone(tester);

  final AppDatabase db = createTestDatabase();
  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      clockProvider.overrideWithValue(() => _now),
      idGeneratorProvider.overrideWithValue(SequentialIdGenerator()),
      locationServiceProvider.overrideWithValue(_FixedLocation()),
    ],
  );
  addTearDown(() async {
    // Descarta a árvore antes do banco: os streams do Drift encerram com ela.
    await tester.pumpWidget(const SizedBox());
    container.dispose();
    await tester.runAsync(db.close);
  });

  await tester.runAsync(() async {
    await _seed(container);
    await prepare?.call(container);
  });

  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: _app(screen)));
  await _settle(tester);
  return container;
}

/// Monta um componente sozinho, numa coluna rolável de 411 de largura.
Future<void> _pumpComponent(WidgetTester tester, Widget child) async {
  _usePhone(tester);
  await tester.pumpWidget(
    _app(
      Scaffold(
        body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: child),
      ),
    ),
  );
  await tester.pump(const Duration(seconds: 1));
}

/// Deixa o banco responder (ele roda fora do relógio falso do teste) e o
/// quadro seguinte desenhar o resultado.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  group('telas com a letra a 200%', () {
    testWidgets('Início', (tester) async {
      await _pumpScreen(tester, const HomePage());
      expect(find.textContaining('Leite integral'), findsWidgets);
      expect(find.textContaining('Café torrado'), findsWidgets);
    });

    testWidgets('Início com a linha do estoque aberta', (tester) async {
      await _pumpScreen(tester, const HomePage());
      await tester.tap(find.textContaining('Leite integral').first);
      await _settle(tester);
      expect(find.byType(QuantityStepper), findsOneWidget);
    });

    testWidgets('Lista', (tester) async {
      await _pumpScreen(tester, const ShoppingListPage());
      expect(find.textContaining('Pão francês'), findsWidgets);
    });

    testWidgets('Lista durante a compra', (tester) async {
      await _pumpScreen(tester, const ShoppingListPage(), prepare: _startTrip);
      expect(find.byType(ShoppingProgress), findsOneWidget);
    });

    testWidgets('Mercados', (tester) async {
      await _pumpScreen(tester, const MarketsPage());
      expect(find.textContaining('Atacadão'), findsWidgets);
    });

    testWidgets('tela do mercado', (tester) async {
      await _pumpScreen(tester, const MarketPage(marketId: _longMarket));
      expect(find.textContaining('Pão de Açúcar'), findsWidgets);
    });

    testWidgets('Produto', (tester) async {
      await _pumpScreen(tester, const ProductDetailPage(productId: _cafe));
      expect(find.textContaining('Café torrado'), findsWidgets);
    });

    testWidgets('Produtos', (tester) async {
      await _pumpScreen(tester, const ProductsPage());
      expect(find.textContaining('Leite integral'), findsWidgets);
    });

    testWidgets('folha "Fim da compra"', (tester) async {
      await _pumpScreen(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showTripReview(
                  context,
                  TripReview(
                    packages: 14,
                    spent: const Money.cents(15890),
                    estimated: true,
                    unpriced: 2,
                    savings: (
                      marketName: 'Supermercado Pão de Açúcar da Avenida Paulista',
                      amount: const Money.cents(1270),
                    ),
                    missing: const [
                      (name: 'Detergente líquido neutro para louças', quantity: 2),
                      (name: 'Pão francês quentinho da padaria', quantity: 6),
                    ],
                  ),
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await _settle(tester);
      expect(find.byType(TripReviewSheet), findsOneWidget);
    });

    testWidgets('folha do item do estoque', (tester) async {
      await _pumpScreen(
        tester,
        Consumer(
          builder: (context, ref, _) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  final product = await ref.read(productRepositoryProvider).findById(_cafe);
                  if (context.mounted) await showStockItemSheet(context, product!);
                },
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await _settle(tester);
      expect(find.byType(StockItemSheet), findsOneWidget);
    });

    testWidgets('bandeja do modo carrinho', (tester) async {
      // O modo carrinho abre a câmera, que o teste não tem: a bandeja é montada
      // com o conteúdo que a tela dá a ela (cart_mode_page.dart).
      await _pumpComponent(
        tester,
        SizedBox(
          height: 900,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ScanTray(
                  title: 'Carrinho',
                  countLabel: '4 de 7 da lista',
                  totalLabel: 'Vou levar',
                  totalValue: r'≈ R$ 154,88',
                  totalNote: 'sem preço de 2 itens',
                  handleLabel: 'Mostrar mais itens',
                  onHandleTap: () {},
                  items: [
                    for (final (index, name) in [
                      '2× Café torrado e moído extraforte tradicional',
                      'Leite integral',
                      '1 de 3 Detergente líquido neutro para louças',
                    ].indexed)
                      ScanTrayItem(
                        name: name,
                        price: index == 1 ? null : r'R$ 1.027,90',
                        priceEstimated: index == 2,
                        take: index != 1,
                        takeLabel: 'Levar $name',
                        onTakeChanged: (_) {},
                        priceTapLabel: 'Digitar o preço',
                        onPriceTap: () {},
                        onNameTap: () {},
                        nameTapLabel: 'Quantidade de $name',
                        justRead: index == 0,
                      ),
                  ],
                  footer: Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: IconButton.filledTonal(
                            onPressed: () {},
                            style: IconButton.styleFrom(fixedSize: const Size.square(48)),
                            icon: const Icon(Icons.keyboard_alt_outlined),
                          ),
                        ),
                      ),
                      ShutterButton(label: 'Fotografar a etiqueta', onPressed: () {}),
                      Expanded(
                        child: Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: FilledButton(
                            onPressed: () {},
                            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                            child: const Text('Terminei'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      expect(find.byType(ScanTrayItem), findsNWidgets(3));
    });
  });

  group('componentes com a letra a 200%', () {
    testWidgets('cabeçalho de seção com selo e ação', (tester) async {
      await _pumpComponent(
        tester,
        Column(
          children: [
            const SectionHeader(title: 'Acabando', count: 128, alert: true),
            SectionHeader(
              title: 'Sua lista em cada mercado da vizinhança',
              count: 12,
              actionLabel: 'Tirar os comprados da lista',
              onAction: () {},
            ),
          ],
        ),
      );
    });

    testWidgets('busca, chip e seletor da câmera', (tester) async {
      await _pumpComponent(
        tester,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BipaSearchBar(hint: 'Buscar o que tem em casa', onChanged: (_) {}, onScan: () {}, scanLabel: 'Bipar'),
            DropdownChip(
              icon: Icons.storefront_outlined,
              label: 'Supermercado Pão de Açúcar da Avenida Paulista',
              onTap: () {},
            ),
            Container(
              color: Colors.black,
              child: CameraModeSwitch<int>(
                options: const [(value: 0, label: 'Etiqueta'), (value: 1, label: 'Código')],
                selected: 0,
                onSelected: (_) {},
              ),
            ),
            const ErrorLine('Escolha o mercado para registrar o preço desta embalagem.'),
          ],
        ),
      );
    });

    testWidgets('chips sobre a câmera', (tester) async {
      await _pumpComponent(
        tester,
        Container(
          color: Colors.black,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CameraGlassChip(
                icon: Icons.storefront_outlined,
                label: 'Supermercado Pão de Açúcar da Avenida Paulista',
                onTap: () {},
              ),
              const LiveReadChip(icon: Icons.sell_outlined, price: r'R$ 1.027,90', detail: 'Arroz Tio João 5 kg'),
              LiveReadChip(
                icon: Icons.sell_outlined,
                price: r'R$ 8,99/kg',
                detail: 'Tomate italiano?',
                actionLabel: 'Desfazer',
                onTap: () {},
              ),
            ],
          ),
        ),
      );
    });

    testWidgets('locais, bloco dos de sempre e cartão de produto', (tester) async {
      await _pumpComponent(
        tester,
        Builder(
          builder: (context) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PlaceFilter<int>(
                options: [
                  for (var i = 0; i < 5; i++)
                    PlaceOption(value: i, label: 'Produtos de limpeza', icon: Icons.kitchen_outlined, count: 120 + i),
                ],
                selected: 1,
                onSelected: (_) {},
              ),
              SizedBox(
                height: QuickTile.sideFor(context),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (var i = 0; i < 4; i++)
                      QuickTile(icon: Icons.coffee_outlined, label: 'Café em pó', selected: i.isOdd, onTap: () {}),
                  ],
                ),
              ),
              SizedBox(
                height: ProductCard.heightFor(context) + 12,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (var i = 0; i < 3; i++)
                      ProductCard(
                        name: 'Detergente líquido neutro para louças',
                        image: const Icon(Icons.local_laundry_service_outlined),
                        gauge: const StockGauge(
                          quantityLabel: '128',
                          state: GaugeState.low,
                          fraction: 0.5,
                          semanticsLabel: '128 de 200 un',
                          size: 36,
                        ),
                        onTap: () {},
                        onToggleList: () {},
                        addLabel: 'Pôr na lista',
                        removeLabel: 'Tirar da lista',
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });

    testWidgets('linhas do estoque, medidor e stepper', (tester) async {
      await _pumpComponent(
        tester,
        StockList(
          children: [
            StockRow(
              id: 'cafe',
              thumb: const SizedBox.square(dimension: 44),
              name: 'Café torrado e moído extraforte tradicional 500 g',
              gauge: const StockGauge(
                quantityLabel: '1,5',
                state: GaugeState.empty,
                fraction: 0,
                semanticsLabel: '1,5 un',
              ),
              expanded: true,
              onTap: () {},
              editor: Padding(
                padding: const EdgeInsets.all(16),
                child: QuantityStepper(
                  value: '128,5',
                  unit: 'emb.',
                  decrementLabel: 'Uma embalagem a menos',
                  incrementLabel: 'Uma embalagem a mais',
                  onIncrement: () {},
                  onDecrement: () {},
                  highlighted: true,
                ),
              ),
            ),
          ],
        ),
      );
    });

    testWidgets('linhas da lista, prévia, progresso e barra da compra', (tester) async {
      await _pumpComponent(
        tester,
        Column(
          children: [
            ListPreviewCard(
              count: 128,
              countLabel: 'itens',
              estimate: r'≈ R$ 1.084,30',
              thumbs: const [Icon(Icons.coffee_outlined), Icon(Icons.egg_outlined), Icon(Icons.eco_outlined)],
              extraCount: 125,
              actionLabel: 'Ir às compras agora',
              actionIcon: Icons.shopping_cart_outlined,
              semanticLabel: 'Lista de compras',
              onTap: () {},
            ),
            const ShoppingProgress(label: '128 de 200', value: 0.6, leading: r'≈ R$ 1.084,30 até agora'),
            ShoppingSectionCard(
              title: 'Mercearia e produtos de limpeza',
              progress: '128/200',
              children: [
                ShoppingListRow(
                  name: 'Café torrado e moído extraforte tradicional',
                  checked: false,
                  onChanged: (_) {},
                  quantity: '12×',
                  quantitySpoken: '12 embalagens',
                  onQuantityTap: () {},
                  price: r'≈ 1.027,90',
                ),
                ShoppingListRow(name: 'Leite', checked: true, onChanged: (_) {}, quantity: '1 de 3', price: '4,79'),
              ],
            ),
            ShoppingBar(
              title: '128 de 200 itens',
              subtitle: r'R$ 1.032,10 · Supermercado Pão de Açúcar',
              actionLabel: 'Continuar',
              progress: 0.6,
              semanticLabel: 'Compra em andamento',
              onTap: () {},
            ),
          ],
        ),
      );
    });

    testWidgets('linhas de preço e comparação', (tester) async {
      await _pumpComponent(
        tester,
        Column(
          children: [
            PriceRowList(
              rows: [
                PriceRowData(
                  icon: Icons.storefront_outlined,
                  title: 'Supermercado Pão de Açúcar da Avenida Paulista',
                  value: r'R$ 1.027,90',
                  meta: r'R$ 5,58/kg · há 12 dias',
                  badge: 'Menor preço por kg',
                  onTap: () {},
                ),
                const PriceRowData(icon: Icons.storefront_outlined, title: 'Atacadão', value: r'R$ 8,99', place: true),
                PriceRowData(
                  icon: Icons.storefront_outlined,
                  title: 'Mercado de bairro com nome comprido',
                  place: true,
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: 16),
            const ListCostCompare(
              bestLabel: 'mais barato',
              rows: [
                ListCostRow(
                  name: 'Supermercado Pão de Açúcar da Avenida Paulista',
                  value: r'R$ 1.084,30',
                  fraction: 0.86,
                ),
                ListCostRow(
                  name: 'Bairro',
                  value: r'R$ 61,70',
                  fraction: 0.63,
                  note: 'sem preço de 2 itens · até 12 dias',
                ),
              ],
            ),
          ],
        ),
      );
    });
  });
}
