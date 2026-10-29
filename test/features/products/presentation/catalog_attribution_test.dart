import 'dart:io';

import 'package:bipa/features/products/data/sqlite_product_catalog.dart';
import 'package:bipa/features/products/domain/product_catalog.dart';
import 'package:bipa/features/products/presentation/products_providers.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_catalog.dart';

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  test('o provider da atribuição lê o aviso de catalog_meta, para a tela "Sobre"', () async {
    final root = await Directory.systemTemp.createTemp('bipa_attribution');
    addTearDown(() => root.delete(recursive: true));
    final file = await writeTestCatalog(File('${root.path}/catalogo.sqlite'), [catalogRow('7893500020110', 'Arroz')]);
    final catalog = SqliteProductCatalog(install: () async => file);
    final container = ProviderContainer(overrides: [productCatalogProvider.overrideWithValue(catalog)]);
    addTearDown(() async {
      container.dispose();
      await catalog.close();
    });

    expect(await container.read(catalogAttributionProvider.future), testCatalogAttribution);
  });

  test('sem catálogo, não há atribuição', () async {
    final container = ProviderContainer(
      overrides: [productCatalogProvider.overrideWithValue(const EmptyProductCatalog())],
    );
    addTearDown(container.dispose);

    expect(await container.read(catalogAttributionProvider.future), isNull);
  });
}
