import 'dart:io';

import 'package:bipa/core/catalog/product_kind.dart';
import 'package:bipa/features/products/data/sqlite_product_catalog.dart';
import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:bipa/features/products/domain/package_origin.dart';
import 'package:bipa/features/products/domain/product_catalog.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_catalog.dart';

void main() {
  late Directory root;
  late Directory support;
  late Uint8List asset;
  late int assetLoads;
  final errors = <Object>[];

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  setUp(() async {
    root = await Directory.systemTemp.createTemp('bipa_catalog');
    support = Directory('${root.path}/suporte')..createSync();
    assetLoads = 0;
    errors.clear();
    final file = await writeTestCatalog(File('${root.path}/asset.sqlite'), [
      catalogRow(
        '7893500020110',
        'Arroz Branco Tipo 1 Tio João',
        brand: 'Tio João',
        quantity: '5 kg',
        sizeValue: 5,
        sizeUnit: 'kg',
        kind: 'grains',
      ),
      catalogRow('7891024134702', 'Sabonete Lux', brand: 'Lux', sizeValue: 85, sizeUnit: 'g', source: 'obf'),
      catalogRow('0012345678905', 'Detergente', sizeUnit: 'litro', kind: 'naoExiste', source: 'opf'),
    ]);
    asset = file.readAsBytesSync();
  });

  tearDown(() => root.delete(recursive: true));

  CatalogInstaller installer({Uint8List? bytes, String? version = '1.0.0+1', bool missing = false}) => CatalogInstaller(
    supportDirectory: () async => support,
    loadAsset: () async {
      assetLoads++;
      return missing ? null : bytes ?? asset;
    },
    versionKey: () async => version,
  );

  SqliteProductCatalog catalogOf(CatalogInstaller installer) {
    final catalog = SqliteProductCatalog(install: installer.install, onError: errors.add);
    addTearDown(catalog.close);
    return catalog;
  }

  group('leitura', () {
    test('acha a embalagem pelo código, com marca, tamanho, unidade, tipo e fonte', () async {
      final catalog = catalogOf(installer());

      expect(
        await catalog.find('7893500020110'),
        const CatalogPackage(
          barcode: '7893500020110',
          name: 'Arroz Branco Tipo 1 Tio João',
          brand: 'Tio João',
          quantity: '5 kg',
          size: 5,
          unit: MeasureUnit.kilogram,
          kind: ProductKind.grains,
          source: PackageOrigin.openFoodFacts,
        ),
      );
      expect((await catalog.find('7891024134702'))?.source, PackageOrigin.openBeautyFacts);
      expect(errors, isEmpty);
    });

    test('um código que o catálogo não tem não acha nada', () async {
      expect(await catalogOf(installer()).find('7890000000000'), isNull);
    });

    test('unidade e tipo que o app não conhece ficam vazios, sem erro', () async {
      final found = await catalogOf(installer()).find('0012345678905');

      expect(
        (found?.unit, found?.kind, found?.size, found?.source),
        (null, null, null, PackageOrigin.openProductsFacts),
      );
      expect(errors, isEmpty);
    });

    test('o UPC-A de 12 dígitos acha o EAN-13 com zero na frente, e vice-versa', () async {
      final catalog = catalogOf(installer());

      expect((await catalog.find('012345678905'))?.name, 'Detergente');
      expect((await catalog.find('0012345678905'))?.name, 'Detergente');
    });

    test('lê o aviso de atribuição de catalog_meta', () async {
      expect(await catalogOf(installer()).attribution(), testCatalogAttribution);
    });

    test('ler não muda o arquivo, que fica fora da pasta do banco da pessoa', () async {
      final catalog = catalogOf(installer());
      await catalog.find('7893500020110');
      await catalog.attribution();
      await catalog.close();

      final file = File('${support.path}/catalogo/catalogo.sqlite');
      expect(file.readAsBytesSync(), asset);
    });
  });

  group('catálogo ausente ou estranho', () {
    test('sem o asset, o catálogo é vazio e não quebra', () async {
      final catalog = catalogOf(installer(missing: true));

      expect(await catalog.find('7893500020110'), isNull);
      expect(await catalog.attribution(), isNull);
      expect(Directory('${support.path}/catalogo').existsSync(), isFalse);
    });

    test('sem a pasta de suporte, o catálogo é vazio e o erro é avisado', () async {
      final catalog = catalogOf(
        CatalogInstaller(
          supportDirectory: () async => throw const FileSystemException('sem pasta'),
          loadAsset: () async => asset,
          versionKey: () async => null,
        ),
      );

      expect(await catalog.find('7893500020110'), isNull);
      expect(errors, hasLength(1));
    });

    test('um arquivo de outro formato (user_version) é tratado como ausente', () async {
      final other = await writeTestCatalog(File('${root.path}/v2.sqlite'), [
        catalogRow('7893500020110', 'Arroz'),
      ], userVersion: 2);

      final catalog = catalogOf(installer(bytes: other.readAsBytesSync()));

      expect(await catalog.find('7893500020110'), isNull);
      expect(errors.single, isA<FormatException>());
    });

    test('um arquivo que não é SQLite não quebra', () async {
      final catalog = catalogOf(installer(bytes: Uint8List.fromList(List.filled(200, 7))));

      expect(await catalog.find('7893500020110'), isNull);
      expect(errors, isNotEmpty);
    });
  });

  group('instalação', () {
    /// Uma execução do app que consulta o catálogo e fecha.
    Future<void> runApp(CatalogInstaller installer) async {
      final catalog = catalogOf(installer);
      await catalog.find('7893500020110');
      await catalog.close();
    }

    test('copia o asset uma vez por versão do app', () async {
      await runApp(installer());
      await runApp(installer());
      expect(assetLoads, 1);

      await runApp(installer(version: '1.1.0+2'));
      expect(assetLoads, 2);
    });

    test('a versão nova do app troca o catálogo pelo dela', () async {
      await runApp(installer());
      final newer = await writeTestCatalog(File('${root.path}/novo.sqlite'), [
        catalogRow('7896005800010', 'Café Pilão', brand: 'Pilão', sizeValue: 500, sizeUnit: 'g'),
      ]);

      final catalog = catalogOf(installer(bytes: newer.readAsBytesSync(), version: '1.1.0+2'));

      expect((await catalog.find('7896005800010'))?.brand, 'Pilão');
      expect(await catalog.find('7893500020110'), isNull);
    });

    test('sem versão (desenvolvimento), copia a cada execução', () async {
      await runApp(installer(version: null));
      await runApp(installer(version: null));

      expect(assetLoads, 2);
    });

    test('uma versão nova sem o asset apaga a cópia antiga', () async {
      await runApp(installer());

      final catalog = catalogOf(installer(version: '1.1.0+2', missing: true));

      expect(await catalog.find('7893500020110'), isNull);
      expect(Directory('${support.path}/catalogo').existsSync(), isFalse);
    });

    test('a primeira consulta instala uma vez, mesmo com várias ao mesmo tempo', () async {
      final catalog = catalogOf(installer());

      await Future.wait([for (var i = 0; i < 5; i++) catalog.find('7893500020110')]);

      expect(assetLoads, 1);
    });
  });
}
