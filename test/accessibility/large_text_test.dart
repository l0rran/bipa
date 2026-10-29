import 'dart:async';
import 'dart:math' as math;

import 'package:bipa/core/crash_reporting/crash_reporting_providers.dart';
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
import 'package:bipa/core/design_system/components/scan_nav_bar.dart';
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
import 'package:bipa/core/widgets/weighed_value_dialog.dart';
import 'package:bipa/features/backup/domain/backup_exception.dart';
import 'package:bipa/features/backup/domain/restore_backup.dart';
import 'package:bipa/features/backup/presentation/backup_providers.dart';
import 'package:bipa/features/backup/presentation/restore_offer_card.dart';
import 'package:bipa/features/backup/presentation/restore_sheet.dart';
import 'package:bipa/features/markets/domain/market.dart';
import 'package:bipa/features/markets/presentation/market_form_page.dart';
import 'package:bipa/features/markets/presentation/market_page.dart';
import 'package:bipa/features/markets/presentation/markets_page.dart';
import 'package:bipa/features/markets/presentation/markets_providers.dart';
import 'package:bipa/features/prices/domain/price_observation.dart';
import 'package:bipa/features/prices/domain/price_source.dart';
import 'package:bipa/features/prices/presentation/price_sheet.dart';
import 'package:bipa/features/prices/presentation/prices_providers.dart';
import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:bipa/features/products/domain/package_suggestion.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/products/domain/product_package.dart';
import 'package:bipa/features/products/presentation/new_package_sheet.dart';
import 'package:bipa/features/products/presentation/package_edit_sheet.dart';
import 'package:bipa/features/products/presentation/product_detail_page.dart';
import 'package:bipa/features/products/presentation/product_form_page.dart';
import 'package:bipa/features/products/presentation/products_page.dart';
import 'package:bipa/features/products/presentation/products_providers.dart';
import 'package:bipa/features/settings/presentation/settings_page.dart';
import 'package:bipa/features/settings/presentation/settings_providers.dart';
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
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../helpers/backup_fakes.dart';
import '../helpers/crash_reporting_fakes.dart';
import '../helpers/fakes.dart';
import '../helpers/test_database.dart';

/// Letra a 200% (WCAG 1.4.4, o máximo do Android): nenhuma tela principal
/// pode cortar texto. O Flutter reporta o `RenderFlex overflow` como erro, e o
/// teste falha com ele, dizendo qual linha estourou.
///
/// Estouro não é tudo (H10): reticência, `maxLines` e `FittedBox` cortam sem
/// erro de layout. Por isso cada tela também passa por [_expectReadable]: o
/// nome de um produto não pode ser cortado, e nenhum texto encolhido por um
/// `FittedBox` pode ficar pequeno demais. Tudo roda em duas larguras: 411 dp
/// (um celular comum) e 360 dp (um celular pequeno).
///
/// As telas são montadas sem o `HomeShell`; a barra de navegação
/// (`ScanNavBar`) entra como componente. O `test/app/home_shell_test.dart`
/// mede a barra de 100% a 200%, com a fonte do app, que este teste não
/// carrega.
const _scale = 2.0;

/// Um celular comum, em pixels lógicos de largura. A altura é grande de
/// propósito: o que está abaixo da dobra só é medido quando entra na tela, e
/// o teste precisa medir tudo.
const _phoneHeight = 4000.0;

/// As larguras em que cada teste roda, em dp.
const _widths = [411.0, 360.0];

/// A largura do teste em andamento; o `setUp` de cada grupo a define.
var _width = 411.0;

/// Trechos dos nomes de produto do [_seed] e dos outros testes: nenhum deles
/// pode aparecer cortado.
const _productNames = ['Café torrado', 'Leite integral', 'Detergente líquido', 'Papel higiênico', 'Pão francês'];

/// O menor tamanho de letra, já com a escala do aparelho, que um texto
/// encolhido por `FittedBox` pode ter. Abaixo disso, deixa de ser legível.
const _minShrunkFontSize = 12.0;

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
    ..physicalSize = Size(_width, _phoneHeight)
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
  List<Override> overrides = const [],
}) async {
  _usePhone(tester);

  final AppDatabase db = createTestDatabase();
  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      clockProvider.overrideWithValue(() => _now),
      idGeneratorProvider.overrideWithValue(SequentialIdGenerator()),
      locationServiceProvider.overrideWithValue(_FixedLocation()),
      ...overrides,
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

/// Mede leitura, não só estouro (H10): falha se um nome de produto foi cortado
/// por `maxLines` ou se um texto foi encolhido por um `FittedBox` até ficar
/// menor que [_minShrunkFontSize].
void _expectReadable(WidgetTester tester) {
  final problems = <String>[];
  for (final element in find.byType(RichText).evaluate()) {
    final paragraph = element.renderObject;
    if (paragraph is! RenderParagraph) continue;
    final text = paragraph.text.toPlainText();
    if (text.trim().isEmpty) continue;

    if (_productNames.any(text.contains) && paragraph.didExceedMaxLines) {
      // Os widgets acima do texto dizem de onde ele vem.
      final owners = <String>[];
      element.visitAncestorElements((ancestor) {
        owners.add(ancestor.widget.runtimeType.toString());
        return owners.length < 12;
      });
      problems.add('nome cortado: "$text" (${owners.join(' < ')})');
    }

    // Quanto os `FittedBox` acima encolheram o texto.
    var shrink = 1.0;
    for (RenderObject? node = paragraph.parent; node != null; node = node.parent) {
      if (node is RenderFittedBox) {
        final child = node.child;
        if (child != null && child.size.width > 0) shrink *= math.min(1, node.size.width / child.size.width);
      }
    }
    final fontSize = paragraph.text.style?.fontSize;
    if (fontSize != null && shrink < 1) {
      final effective = paragraph.textScaler.scale(fontSize) * shrink;
      if (effective < _minShrunkFontSize) {
        problems.add('texto encolhido para ${effective.toStringAsFixed(1)}: "$text"');
      }
    }
  }
  expect(problems, isEmpty, reason: 'texto ilegível a ${_width.toInt()} dp');
}

/// Deixa o banco responder (ele roda fora do relógio falso do teste) e o
/// quadro seguinte desenhar o resultado.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump(const Duration(seconds: 1));
  _expectReadable(tester);
}

void main() {
  for (final width in _widths) {
    group('a ${width.toInt()} dp', () {
      setUp(() => _width = width);
      _tests();
    });
  }
}

void _tests() {
  group('telas com a letra a 200%', () {
    testWidgets('Início', (tester) async {
      await _pumpScreen(tester, const HomePage());
      expect(find.textContaining('Leite integral'), findsWidgets);
      expect(find.textContaining('Café torrado'), findsWidgets);
    });

    testWidgets('Início com a pergunta do relatório de falhas', (tester) async {
      // Compra terminada, build com DSN e nenhuma resposta: o cartão aparece.
      await _pumpScreen(
        tester,
        const HomePage(),
        prepare: (container) async {
          final trips = container.read(shoppingTripRepositoryProvider);
          await trips.finish((await trips.start()).id);
        },
        overrides: [
          crashReporterProvider.overrideWithValue(FakeCrashReporter()),
          // O app foi aberto de novo depois da compra.
          appSessionStartProvider.overrideWithValue(DateTime(2100)),
        ],
      );
      expect(find.text('Se o Bipa travar, mandar um relatório?'), findsOneWidget);
      expect(find.text('Mandar'), findsOneWidget);
      expect(find.text('Não mandar'), findsOneWidget);
      expect(find.textContaining('Leite integral'), findsWidgets);
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
      // O café, de nome comprido, tem duas embalagens: a linha traz a conta,
      // o preço por kg e o que ele mede, e o cadastro fecha a lista.
      expect(find.textContaining('Café torrado'), findsWidgets);
      expect(find.text('2 embalagens'), findsOneWidget);
      expect(find.text('o kg'), findsWidgets);
      expect(find.text('Cadastrar produto'), findsOneWidget);
    });

    testWidgets('Ajustes', (tester) async {
      await _pumpScreen(
        tester,
        const SettingsPage(),
        overrides: [
          crashReporterProvider.overrideWithValue(FakeCrashReporter()),
          appVersionProvider.overrideWith((ref) async => '0.1.0'),
          backupProvider.overrideWith(
            () => FakeBackupController(
              initial: BackupState(
                lastBackup: fakeBackupInfo(createdAt: _now, size: 30 * 1024 * 1024),
              ),
            ),
          ),
        ],
      );
      // O grupo "Backup", com a frase mais longa: a do tamanho acima de 25 MB.
      expect(find.text('Último backup'), findsOneWidget);
      expect(find.textContaining('Com 30 MB'), findsOneWidget);
      expect(find.text('Salvar uma cópia…'), findsOneWidget);
      expect(find.text('Relatório de falhas'), findsOneWidget);
      expect(find.text('O que nunca vai'), findsOneWidget);
      // Com o grupo do backup, a versão fica abaixo da dobra mesmo aqui.
      await tester.scrollUntilVisible(find.text('0.1.0'), 400);
      await tester.pump();
      _expectReadable(tester);
      expect(find.text('0.1.0'), findsOneWidget);
    });

    testWidgets('Ajustes com o backup de outro celular, e o diálogo de gravar por cima', (tester) async {
      final pending = fakeBackupInfo(createdAt: DateTime(2026, 10, 12, 21), madeHere: false);
      await _pumpScreen(
        tester,
        const SettingsPage(),
        overrides: [
          crashReporterProvider.overrideWithValue(FakeCrashReporter()),
          appVersionProvider.overrideWith((ref) async => '0.1.0'),
          backupProvider.overrideWith(
            () => FakeBackupController(
              initial: BackupState(lastBackup: pending, restoreOffer: pending),
            ),
          ),
        ],
      );
      expect(find.text('Veio do backup do Google. Toque para restaurar.'), findsOneWidget);
      expect(find.text('2026'), findsOneWidget);
      expect(find.text('Automático pausado até você decidir'), findsOneWidget);
      _expectReadable(tester);

      await tester.tap(find.text('Fazer backup agora'));
      await _settle(tester);
      expect(find.text('Apagar o backup que veio do Google?'), findsOneWidget);
      expect(find.text('Apagar e fazer backup'), findsOneWidget);
      _expectReadable(tester);
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

    /// A folha de restaurar um backup, com a conferência de [preparing].
    Future<void> openRestoreSheet(WidgetTester tester, Future<PreparedRestore> Function() preparing) async {
      await _pumpScreen(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showRestoreSheet(
                  context,
                  preparing: preparing(),
                  fileName: 'bipa-2026-10-12.bipa',
                  onPickAnother: () {},
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
        overrides: [backupProvider.overrideWith(FakeBackupController.new)],
      );
      await tester.tap(find.text('abrir'));
      await _settle(tester);
    }

    testWidgets('folha "Restaurar o backup", conferindo', (tester) async {
      await openRestoreSheet(tester, () => Completer<PreparedRestore>().future);
      expect(find.text('Conferindo o arquivo'), findsOneWidget);
      expect(find.text('Substituir pelo backup'), findsOneWidget);
    });

    testWidgets('folha "Restaurar o backup", com os números', (tester) async {
      await openRestoreSheet(
        tester,
        () async => fakePrepared(createdAt: DateTime(2026, 10, 12, 21), adjustedItems: 2, currentLatestActivity: _now),
      );
      expect(find.text('Restaurar o backup de 12/10/2026?'), findsOneWidget);
      expect(find.textContaining('saem deste celular'), findsOneWidget);
      expect(find.text('Neste celular agora: 230 produtos, 1.452 preços e 60 itens em casa.'), findsOneWidget);
      expect(find.textContaining('quantidade acertada'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
    });

    testWidgets('folha de backup que não abre', (tester) async {
      await openRestoreSheet(tester, () async => throw const BackupException.notRecognized());
      expect(find.text('Não deu para abrir este backup'), findsOneWidget);
      expect(find.text('Escolher outro arquivo'), findsOneWidget);
    });

    testWidgets('folha de backup de um Bipa mais novo', (tester) async {
      await openRestoreSheet(tester, () async => throw const BackupException.fromNewerApp());
      expect(find.text('Este backup é de um Bipa mais novo'), findsOneWidget);
      expect(find.text('Atualizar o Bipa'), findsOneWidget);
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

    testWidgets('cartão "Backup encontrado" do celular novo', (tester) async {
      // O Início do [_pumpScreen] tem dados, e o cartão só aparece com o banco
      // vazio: ele é montado sozinho, como o Início o mostra.
      final offer = fakeBackupInfo(createdAt: DateTime(2026, 10, 12, 21), madeHere: false);
      await _pumpComponent(
        tester,
        ProviderScope(
          overrides: [
            backupProvider.overrideWith(() => FakeBackupController(initial: BackupState(restoreOffer: offer))),
          ],
          child: RestoreOfferCard(offer: offer),
        ),
      );
      _expectReadable(tester);
      expect(find.text('Restaurar o backup de 12/10/2026?'), findsOneWidget);
      expect(find.text('Restaurar'), findsOneWidget);
      expect(find.text('Começar do zero'), findsOneWidget);
    });

    testWidgets('cartão menor do backup de outro celular, com a casa em uso', (tester) async {
      final offer = fakeBackupInfo(createdAt: DateTime(2026, 10, 12, 21), madeHere: false);
      await _pumpComponent(
        tester,
        ProviderScope(
          overrides: [
            backupProvider.overrideWith(() => FakeBackupController(initial: BackupState(restoreOffer: offer))),
          ],
          child: PendingBackupCard(offer: offer),
        ),
      );
      _expectReadable(tester);
      expect(find.text('Restaurar o backup de 12/10/2026?'), findsOneWidget);
      expect(find.text('214 produtos, 1.380 preços e 56 itens em casa'), findsOneWidget);
      expect(find.text('Deixar de lado'), findsOneWidget);
      // A 200%, os botões ficam um embaixo do outro.
      expect(
        tester.getTopLeft(find.text('Deixar de lado')).dy,
        greaterThan(tester.getBottomLeft(find.text('Restaurar')).dy),
      );
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
                  // Toda a lista à mostra: o teste mede os três itens.
                  maxListHeight: 1200,
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
                        // O granel que espera a pesagem: o preço por kg sob o nome.
                        meta: index == 1 ? r'R$ 1.027,90/kg' : null,
                        metaIcon: index == 1 ? Icons.scale_outlined : null,
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

  group('formulários e folhas com a letra a 200%', () {
    /// Abre [sheet] numa folha de baixo, como o app faz. A câmera não monta no
    /// teste, mas as folhas que ela abre (embalagem nova) montam.
    Future<void> openSheet(WidgetTester tester, Widget Function(BuildContext context) sheet) async {
      await _pumpScreen(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showModalBottomSheet<void>(context: context, isScrollControlled: true, builder: sheet),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await _settle(tester);
    }

    testWidgets('diálogo "Quanto deu" da pesagem, com a conta de volta', (tester) async {
      await _pumpScreen(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showWeighedValueDialog(
                  context,
                  title: 'Quanto deu o Tomate italiano de talo comprido?',
                  initial: const Money.cents(1240),
                  backFor: (_) => (text: r'1,38 kg a R$ 8,99/kg', spoken: r'1,38 kg a R$ 8,99 o quilo'),
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await _settle(tester);
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text(r'1,38 kg a R$ 8,99/kg'), findsOneWidget);
    });

    testWidgets('formulário de produto novo', (tester) async {
      await _pumpScreen(
        tester,
        const ProductFormPage(
          args: ProductFormArgs(barcode: '7891234567890', name: 'Detergente líquido neutro para louças'),
        ),
      );
      expect(find.byType(TextFormField), findsWidgets);
    });

    testWidgets('formulário de produto existente', (tester) async {
      await _pumpScreen(tester, const ProductFormPage(productId: _cafe));
      expect(find.byType(TextFormField), findsWidgets);
    });

    testWidgets('formulário de mercado novo', (tester) async {
      await _pumpScreen(tester, const MarketFormPage(here: true));
      expect(find.byType(TextFormField), findsWidgets);
    });

    testWidgets('formulário de mercado existente', (tester) async {
      await _pumpScreen(tester, const MarketFormPage(marketId: _longMarket));
      expect(find.byType(TextFormField), findsWidgets);
    });

    testWidgets('folha "Embalagem nova" com produto sugerido', (tester) async {
      await openSheet(
        tester,
        (_) => NewPackageSheet(
          barcode: '7891234567890',
          price: const Money.cents(2890),
          suggestion: PackageSuggestion(
            product: Product(
              id: _detergente,
              name: 'Detergente líquido neutro para louças',
              unit: MeasureUnit.milliliter,
              createdAt: _now,
              updatedAt: _now,
            ),
            brand: 'Ypê Premium Maçã Verde',
            size: 500,
            unit: MeasureUnit.milliliter,
          ),
        ),
      );
      expect(find.byType(NewPackageSheet), findsOneWidget);
    });

    testWidgets('folha "Embalagem nova" com produto novo', (tester) async {
      await openSheet(
        tester,
        (_) => const NewPackageSheet(
          barcode: '7891234567890',
          suggestion: PackageSuggestion(
            newProductName: 'Arroz',
            brand: 'Tio João Tradicional',
            size: 5,
            unit: MeasureUnit.kilogram,
          ),
        ),
      );
      expect(find.byType(NewPackageSheet), findsOneWidget);
    });

    testWidgets('folha do preço', (tester) async {
      final observation = PriceObservation(
        id: 'o-folha',
        productId: _cafe,
        packageId: 'p-cafe',
        marketId: _longMarket,
        price: const Money.cents(2890),
        source: PriceSource.priceTag,
        observedAt: _now.subtract(const Duration(days: 12)),
        createdAt: _now.subtract(const Duration(days: 12)),
      );
      await openSheet(
        tester,
        (_) => PriceSheet(
          observation: observation,
          title: 'Supermercado Pão de Açúcar da Avenida Paulista',
          openLabel: 'Ver o mercado',
          onOpen: () {},
        ),
      );
      expect(find.byType(PriceSheet), findsOneWidget);
    });

    testWidgets('folha "Editar embalagem"', (tester) async {
      await openSheet(
        tester,
        (_) => PackageEditSheet(
          package: ProductPackage(
            id: 'p-cafe',
            productId: _cafe,
            unit: MeasureUnit.gram,
            size: 500,
            brand: 'Pilão Tradicional Extraforte',
            barcode: '789p-cafe',
            createdAt: _now,
            updatedAt: _now,
          ),
        ),
      );
      expect(find.byType(PackageEditSheet), findsOneWidget);
    });
  });

  group('componentes com a letra a 200%', () {
    testWidgets('barra de navegação, com o bipar flutuando acima dela', (tester) async {
      _usePhone(tester);
      await tester.pumpWidget(
        _app(
          Scaffold(
            extendBody: true,
            body: const SizedBox.expand(),
            bottomNavigationBar: ScanNavBar(
              destinations: const [
                ScanNavDestination(icon: Icons.home_outlined, selectedIcon: Icons.home_rounded, label: 'Início'),
                ScanNavDestination(icon: Icons.sell_outlined, selectedIcon: Icons.sell_rounded, label: 'Produtos'),
                ScanNavDestination(icon: Icons.place_outlined, selectedIcon: Icons.place_rounded, label: 'Mercados'),
                ScanNavDestination(
                  icon: Icons.checklist_outlined,
                  selectedIcon: Icons.checklist_rounded,
                  label: 'Lista',
                ),
              ],
              selectedIndex: 0,
              onSelected: (_) {},
              onScan: () {},
              scanLabel: 'Bipar',
              onScanLongPress: (_) {},
              compact: true,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      _expectReadable(tester);
      // Os rótulos encolhem até caber, mas nunca são cortados; e a 200% a
      // barra ignora o pedido para encolher.
      for (final label in ['Início', 'Produtos', 'Mercados', 'Lista']) {
        final paragraph = tester.renderObject<RenderParagraph>(find.text(label));
        expect(paragraph.didExceedMaxLines, isFalse, reason: '"$label" cortado a ${_width.toInt()} dp');
        final opacity = tester.widget<Opacity>(
          find.ancestor(of: find.text(label), matching: find.byType(Opacity)).first,
        );
        expect(opacity.opacity, 1);
      }
    });

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
              // O item novo em casa: o nome em cima e o local embaixo (AB12).
              LiveReadChip(
                icon: Icons.home_outlined,
                price: '+1',
                title: 'Leite integral 1 L',
                detail: '1 na Despensa',
                onDetailTap: () {},
                detailActionLabel: 'trocar o local',
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
                height: QuickTile.sideFor(context, labels: const ['Café em pó']),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (var i = 0; i < 4; i++)
                      QuickTile(icon: Icons.coffee_outlined, label: 'Café em pó', selected: i.isOdd, onTap: () {}),
                  ],
                ),
              ),
              SizedBox(
                height: ProductCard.heightFor(context, names: const ['Detergente líquido neutro para louças']) + 12,
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
