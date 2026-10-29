import 'package:bipa/core/database/app_database.dart';
import 'package:bipa/core/database/database_provider.dart';
import 'package:bipa/core/design_system/bipa_palette.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/design_system/bipa_typography.dart';
import 'package:bipa/core/di/core_providers.dart';
import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/products/domain/product_package.dart';
import 'package:bipa/features/products/presentation/package_edit_sheet.dart';
import 'package:bipa/features/products/presentation/products_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/test_database.dart';

final _now = DateTime(2026, 10, 28, 9);

final _package = ProductPackage(
  id: 'camil-10',
  productId: 'arroz',
  barcode: '7896006711155',
  brand: 'Camil',
  size: 10,
  unit: MeasureUnit.kilogram,
  createdAt: _now,
  updatedAt: _now,
);

Future<ProviderContainer> _pumpSheet(WidgetTester tester) async {
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
    final products = container.read(productRepositoryProvider);
    await products.save(
      Product(id: 'arroz', name: 'Arroz branco', unit: MeasureUnit.kilogram, createdAt: _now, updatedAt: _now),
    );
    await products.savePackage(_package);
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: BipaTheme.light,
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
        home: Scaffold(body: PackageEditSheet(package: _package)),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('os campos aparecem sobre a folha, e o código vem na fonte dos códigos', (tester) async {
    await _pumpSheet(tester);

    for (final field in tester.widgetList<TextField>(find.byType(TextField))) {
      expect(field.decoration?.fillColor, BipaPalette.light.surfaceSunken);
    }
    expect(tester.widget<Text>(find.text('7896006711155')).style?.fontFamily, BipaFonts.mono);
  });

  testWidgets('a unidade fica dentro do campo do tamanho, como na "Embalagem nova"', (tester) async {
    await _pumpSheet(tester);

    final size = find.ancestor(of: find.text('10'), matching: find.byType(TextField));
    expect(find.descendant(of: size, matching: find.byType(DropdownButton<MeasureUnit>)), findsOneWidget);
    expect(find.byType(DropdownMenu<MeasureUnit>), findsNothing);
  });

  testWidgets('salvar grava a marca, o tamanho e a unidade', (tester) async {
    final container = await _pumpSheet(tester);

    await tester.enterText(find.ancestor(of: find.text('10'), matching: find.byType(TextField)), '5');
    await tester.tap(find.text('kg'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('g').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();

    final saved = await tester.runAsync(() => container.read(productRepositoryProvider).findPackageById('camil-10'));
    expect(saved?.size, 5);
    expect(saved?.unit, MeasureUnit.gram);
    expect(saved?.brand, 'Camil');
  });

  testWidgets('um tamanho que não é número não salva e diz o que está errado', (tester) async {
    await _pumpSheet(tester);

    await tester.enterText(find.ancestor(of: find.text('10'), matching: find.byType(TextField)), 'dez');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(find.text('O tamanho precisa ser um número, como 5 ou 0,5.'), findsOneWidget);
  });
}
