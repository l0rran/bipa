import 'package:bipa/features/prices/domain/price_observation.dart';
import 'package:bipa/features/prices/domain/product_headline_price.dart';
import 'package:bipa/features/prices/presentation/prices_providers.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/products/domain/product_package.dart';
import 'package:bipa/features/products/presentation/products_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Um produto da lista de Produtos com o que a linha dele mostra.
typedef ProductRow = ({Product product, List<ProductPackage> packages, HeadlinePrice? price});

/// As embalagens dos produtos da lista, numa consulta só.
final _listPackagesProvider = StreamProvider.autoDispose<List<ProductPackage>>((ref) async* {
  // O ref não pode ser usado depois do await: o provider pode ter sido
  // reconstruído nesse meio-tempo.
  final products = ref.watch(productRepositoryProvider);
  final items = await ref.watch(productsProvider.future);
  yield* products.watchPackagesOfProducts({for (final item in items) item.id});
});

/// O histórico de preços dos produtos da lista, numa consulta só.
final _listHistoryProvider = StreamProvider.autoDispose<List<PriceHistoryEntry>>((ref) async* {
  final prices = ref.watch(priceRepositoryProvider);
  final items = await ref.watch(productsProvider.future);
  yield* prices.watchHistoryOfProducts({for (final item in items) item.id});
});

/// Os produtos da lista (com a busca aplicada), em ordem alfabética, cada um
/// com as embalagens e o preço da linha. Só sai do carregando quando tudo
/// chegou, para a linha não aparecer sem o preço e depois ganhá-lo.
final productRowsProvider = Provider.autoDispose<AsyncValue<List<ProductRow>>>((ref) {
  final products = ref.watch(productsProvider);
  final packages = ref.watch(_listPackagesProvider);
  final history = ref.watch(_listHistoryProvider);

  if (products.hasError) return AsyncError(products.error!, products.stackTrace!);
  if (packages.hasError) return AsyncError(packages.error!, packages.stackTrace!);
  if (history.hasError) return AsyncError(history.error!, history.stackTrace!);
  final items = products.value;
  final allPackages = packages.value;
  final allHistory = history.value;
  if (items == null || allPackages == null || allHistory == null) return const AsyncLoading();

  final packagesByProduct = <String, List<ProductPackage>>{};
  for (final package in allPackages) {
    packagesByProduct.putIfAbsent(package.productId, () => []).add(package);
  }
  final historyByProduct = <String, List<PriceHistoryEntry>>{};
  for (final entry in allHistory) {
    historyByProduct.putIfAbsent(entry.observation.productId, () => []).add(entry);
  }
  ProductRow rowOf(Product product) {
    final packages = packagesByProduct[product.id] ?? const <ProductPackage>[];
    final history = historyByProduct[product.id] ?? const <PriceHistoryEntry>[];
    return (
      product: product,
      packages: packages,
      price: headlinePrice(product: product, packages: packages, history: history),
    );
  }

  return AsyncData([for (final product in items) rowOf(product)]);
});
