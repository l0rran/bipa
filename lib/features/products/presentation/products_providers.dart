import 'package:bipa/core/database/database_provider.dart';
import 'package:bipa/features/products/data/drift_product_repository.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/products/domain/product_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final productRepositoryProvider = Provider<ProductRepository>(
  (ref) => DriftProductRepository(ref.watch(appDatabaseProvider)),
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
