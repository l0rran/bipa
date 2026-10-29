import 'package:bipa/core/catalog/product_kind.dart';
import 'package:bipa/core/database/app_database.dart';
import 'package:bipa/core/database/database_provider.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/di/core_providers.dart';
import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:bipa/features/products/domain/package_origin.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/products/domain/product_catalog.dart';
import 'package:bipa/features/products/domain/product_package.dart';
import 'package:bipa/features/products/presentation/new_package_sheet.dart';
import 'package:bipa/features/products/presentation/products_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/test_database.dart';

final _now = DateTime(2026, 10, 29, 9);

const _riceCode = '7893500020110';
const _beansCode = '7896006711155';

/// Um catálogo com um só produto, o arroz.
final class _FakeCatalog implements ProductCatalog {
  const _FakeCatalog();

  @override
  Future<CatalogPackage?> find(String barcode) async => barcode == _riceCode
      ? const CatalogPackage(
          barcode: _riceCode,
          name: 'ARROZ BRANCO TIPO 1 TIO JOAO',
          brand: 'TIO JOÃO',
          size: 5,
          unit: MeasureUnit.kilogram,
          kind: ProductKind.grains,
          source: PackageOrigin.openFoodFacts,
        )
      : null;

  @override
  Future<String?> attribution() async => null;
}

/// Um catálogo que falha em toda consulta.
final class _BrokenCatalog implements ProductCatalog {
  const _BrokenCatalog();

  @override
  Future<CatalogPackage?> find(String barcode) async => throw Exception('catálogo quebrado');

  @override
  Future<String?> attribution() async => throw Exception('catálogo quebrado');
}

/// Uma tela com um botão que bipa [code] (com o nome lido na etiqueta
/// [nameHint]) e abre a "Embalagem nova", como a câmera e o carrinho fazem.
Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required ProductCatalog catalog,
  required String code,
  String? nameHint,
}) async {
  final AppDatabase db = createTestDatabase();
  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      clockProvider.overrideWithValue(() => _now),
      idGeneratorProvider.overrideWithValue(SequentialIdGenerator()),
      productCatalogProvider.overrideWithValue(catalog),
    ],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    container.dispose();
    await tester.runAsync(db.close);
  });
  await tester.runAsync(
    () => container
        .read(productRepositoryProvider)
        .save(Product(id: 'arroz', name: 'Arroz branco', unit: MeasureUnit.kilogram, createdAt: _now, updatedAt: _now)),
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: BipaTheme.light,
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () => showNewPackageSheet(context, ref, barcode: code, nameHint: nameHint),
              child: const Text('bipar'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('bipar'));
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  await tester.pumpAndSettle();
  return container;
}

String _field(WidgetTester tester, String label) =>
    tester.widget<TextField>(find.ancestor(of: find.text(label), matching: find.byType(TextField))).controller!.text;

Future<ProductPackage?> _save(WidgetTester tester, ProviderContainer container, String code) async {
  await tester.tap(find.text('Salvar'));
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
  await tester.pumpAndSettle();
  return tester.runAsync<ProductPackage?>(() => container.read(productRepositoryProvider).findPackageByBarcode(code));
}

void main() {
  testWidgets('um código do catálogo abre a folha preenchida, e a embalagem nasce marcada como dele', (tester) async {
    final container = await _pump(tester, catalog: const _FakeCatalog(), code: _riceCode);

    // O produto da pessoa vem pelo nome do catálogo; marca e tamanho, dele.
    expect(find.text('Arroz branco'), findsOneWidget);
    expect(_field(tester, 'Marca'), 'Tio João');
    expect(_field(tester, 'Tamanho'), '5');
    expect(find.text('kg'), findsOneWidget);

    final saved = await _save(tester, container, _riceCode);
    expect(
      (saved?.productId, saved?.brand, saved?.size, saved?.unit, saved?.origin),
      ('arroz', 'Tio João', 5.0, MeasureUnit.kilogram, PackageOrigin.openFoodFacts),
    );
  });

  testWidgets('um código fora do catálogo segue como antes, pelo nome da etiqueta', (tester) async {
    final container = await _pump(
      tester,
      catalog: const _FakeCatalog(),
      code: _beansCode,
      nameHint: 'FEIJAO CARIOCA CAMIL 1KG',
    );

    expect(find.text('Feijão'), findsOneWidget);
    expect(_field(tester, 'Marca'), 'Camil');
    expect(_field(tester, 'Tamanho'), '1');

    final saved = await _save(tester, container, _beansCode);
    expect((saved?.brand, saved?.origin), ('Camil', PackageOrigin.person));
  });

  testWidgets('sem catálogo, a folha abre como antes', (tester) async {
    await _pump(tester, catalog: const EmptyProductCatalog(), code: _riceCode, nameHint: 'ARROZ BRANCO 5KG');

    expect(find.text('Arroz branco'), findsOneWidget);
    expect(_field(tester, 'Marca'), '');
    expect(_field(tester, 'Tamanho'), '5');
  });

  testWidgets('um catálogo que falha não impede o cadastro', (tester) async {
    final container = await _pump(tester, catalog: const _BrokenCatalog(), code: _riceCode);

    // Sem nome na etiqueta, a folha pede o produto, como sem catálogo.
    expect(find.text('Escolher o produto'), findsOneWidget);
    expect(container.read(productCatalogProvider), isA<_BrokenCatalog>());
  });
}
