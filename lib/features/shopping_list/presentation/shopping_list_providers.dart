import 'package:bipa/core/database/database_provider.dart';
import 'package:bipa/core/di/core_providers.dart';
import 'package:bipa/core/money/money.dart';
import 'package:bipa/features/prices/domain/price_comparison.dart';
import 'package:bipa/features/prices/presentation/prices_providers.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/products/presentation/products_providers.dart';
import 'package:bipa/features/shopping_list/data/drift_shopping_list_repository.dart';
import 'package:bipa/features/shopping_list/domain/shopping_list_item.dart';
import 'package:bipa/features/shopping_list/domain/shopping_list_repository.dart';
import 'package:bipa/features/shopping_list/domain/shopping_list_sections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final shoppingListRepositoryProvider = Provider<ShoppingListRepository>(
  (ref) => DriftShoppingListRepository(
    ref.watch(appDatabaseProvider),
    ids: ref.watch(idGeneratorProvider),
    clock: ref.watch(clockProvider),
  ),
);

final shoppingListProvider = StreamProvider.autoDispose<List<ShoppingListEntry>>(
  (ref) => ref.watch(shoppingListRepositoryProvider).watchAll(),
);

/// Preço de referência dos produtos da lista, para estimar o total.
final shoppingListPricesProvider = StreamProvider.autoDispose<Map<String, Money>>((ref) async* {
  // O ref não pode ser usado depois do await: o provider pode ter sido
  // reconstruído nesse meio-tempo.
  final prices = ref.watch(priceRepositoryProvider);
  final entries = await ref.watch(shoppingListProvider.future);
  final productIds = {for (final entry in entries) ?entry.item.productId};
  yield* prices.watchHistoryOfProducts(productIds).map(referencePrices);
});

final shoppingListSummaryProvider = Provider.autoDispose<ShoppingListSummary>((ref) {
  final entries = ref.watch(shoppingListProvider).value ?? const [];
  final prices = ref.watch(shoppingListPricesProvider).value ?? const {};
  return ShoppingListSummary.of(entries, prices);
});

/// Produtos que ainda faltam comprar, para marcar "na lista" na Casa.
final productsOnListProvider = Provider.autoDispose<Set<String>>((ref) {
  final entries = ref.watch(shoppingListProvider).value ?? const [];
  return {
    for (final entry in entries)
      if (!entry.item.isChecked) ?entry.item.productId,
  };
});

/// Produtos cujo nome contém o que está sendo digitado no campo da lista.
final listProductSuggestionsProvider = StreamProvider.autoDispose.family<List<Product>, String>(
  (ref, query) => ref.watch(productRepositoryProvider).watchAll(query: query),
);
