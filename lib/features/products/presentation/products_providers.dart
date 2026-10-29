import 'package:bipa/core/database/database_provider.dart';
import 'package:bipa/core/di/core_providers.dart';
import 'package:bipa/features/products/data/directory_product_photo_files.dart';
import 'package:bipa/features/products/data/drift_product_repository.dart';
import 'package:bipa/features/products/data/sqlite_product_catalog.dart';
import 'package:bipa/features/products/domain/create_product_by_weight.dart';
import 'package:bipa/features/products/domain/delete_package.dart';
import 'package:bipa/features/products/domain/move_package.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/products/domain/product_catalog.dart';
import 'package:bipa/features/products/domain/product_package.dart';
import 'package:bipa/features/products/domain/product_repository.dart';
import 'package:bipa/features/products/domain/register_package.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

final productRepositoryProvider = Provider<ProductRepository>(
  (ref) => DriftProductRepository(
    ref.watch(appDatabaseProvider),
    clock: ref.watch(clockProvider),
    ids: ref.watch(idGeneratorProvider),
    photos: DirectoryProductPhotoFiles(productPhotosDirectory),
  ),
);

/// O catálogo pronto de produtos (ADR 0024), copiado do asset para a pasta
/// de suporte na primeira consulta de cada versão do app. Sem o asset, é
/// vazio. Sobrescreva em testes.
final productCatalogProvider = Provider<ProductCatalog>((ref) {
  final catalog = SqliteProductCatalog(
    install: CatalogInstaller(
      supportDirectory: getApplicationSupportDirectory,
      loadAsset: _loadCatalogAsset,
      versionKey: () async {
        // Em desenvolvimento, o catálogo muda sem a versão mudar: a cópia é
        // refeita a cada execução.
        if (!kReleaseMode) return null;
        final info = await PackageInfo.fromPlatform();
        return '${info.version}+${info.buildNumber}';
      },
    ).install,
    onError: (error) => debugPrint('Catálogo pronto indisponível: $error'),
  );
  ref.onDispose(catalog.close);
  return catalog;
});

Future<Uint8List?> _loadCatalogAsset() async {
  try {
    final data = await rootBundle.load(catalogAsset);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  } on FlutterError {
    // O asset não foi declarado no pubspec: o app segue sem catálogo.
    return null;
  }
}

/// O aviso de atribuição do catálogo (`catalog_meta.attribution`), para a
/// tela "Sobre" (ADR 0024); `null` sem catálogo.
final catalogAttributionProvider = FutureProvider<String?>((ref) => ref.watch(productCatalogProvider).attribution());

/// Texto digitado na busca da lista de produtos.
final productSearchQueryProvider = NotifierProvider<ProductSearchQuery, String>(ProductSearchQuery.new);

class ProductSearchQuery extends Notifier<String> {
  @override
  String build() => '';

  void change(String query) => state = query;
}

final productsProvider = StreamProvider.autoDispose<List<Product>>((ref) {
  final query = ref.watch(productSearchQueryProvider);
  return ref.watch(productRepositoryProvider).watchAll(query: query);
});

final productProvider = StreamProvider.autoDispose.family<Product?, String>(
  (ref, id) => ref.watch(productRepositoryProvider).watchById(id),
);

/// As embalagens do produto, das mais novas para as mais antigas.
final productPackagesProvider = StreamProvider.autoDispose.family<List<ProductPackage>, String>(
  (ref, productId) => ref.watch(productRepositoryProvider).watchPackages(productId),
);

final registerPackageProvider = Provider<RegisterPackage>(
  (ref) => RegisterPackage(
    products: ref.watch(productRepositoryProvider),
    ids: ref.watch(idGeneratorProvider),
    clock: ref.watch(clockProvider),
  ),
);

/// "Mover para outro produto…" (ADR 0022).
final movePackageProvider = Provider<MovePackage>(
  (ref) => MovePackage(
    products: ref.watch(productRepositoryProvider),
    ids: ref.watch(idGeneratorProvider),
    clock: ref.watch(clockProvider),
  ),
);

/// "Apagar embalagem", com o "Desfazer" (ADR 0022).
final deletePackageProvider = Provider<DeletePackage>(
  (ref) => DeletePackage(products: ref.watch(productRepositoryProvider)),
);

/// Cadastra um produto vendido por quilo (ADR 0018).
final createProductByWeightProvider = Provider<CreateProductByWeight>(
  (ref) => CreateProductByWeight(
    products: ref.watch(productRepositoryProvider),
    ids: ref.watch(idGeneratorProvider),
    clock: ref.watch(clockProvider),
  ),
);
