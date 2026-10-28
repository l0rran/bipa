import 'package:bipa/core/database/database_provider.dart';
import 'package:bipa/core/di/core_providers.dart';
import 'package:bipa/features/products/data/drift_product_repository.dart';
import 'package:bipa/features/products/domain/create_product_by_weight.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/products/domain/product_package.dart';
import 'package:bipa/features/products/domain/product_repository.dart';
import 'package:bipa/features/products/domain/register_package.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final productRepositoryProvider = Provider<ProductRepository>(
  (ref) => DriftProductRepository(ref.watch(appDatabaseProvider), clock: ref.watch(clockProvider)),
);

/// Texto digitado na busca da lista de produtos.
final productSearchQueryProvider = NotifierProvider<ProductSearchQuery, String>(
  ProductSearchQuery.new,
);

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

/// Cadastra um produto vendido por quilo (ADR 0018).
final createProductByWeightProvider = Provider<CreateProductByWeight>(
  (ref) => CreateProductByWeight(
    products: ref.watch(productRepositoryProvider),
    ids: ref.watch(idGeneratorProvider),
    clock: ref.watch(clockProvider),
  ),
);
