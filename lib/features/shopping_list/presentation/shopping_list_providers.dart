import 'package:bipa/core/database/database_provider.dart';
import 'package:bipa/core/di/core_providers.dart';
import 'package:bipa/features/markets/presentation/markets_providers.dart';
import 'package:bipa/core/money/money.dart';
import 'package:bipa/features/prices/domain/price_comparison.dart';
import 'package:bipa/features/prices/domain/price_observation.dart';
import 'package:bipa/features/prices/presentation/prices_providers.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/products/presentation/products_providers.dart';
import 'package:bipa/features/shopping_list/data/drift_shopping_list_repository.dart';
import 'package:bipa/features/shopping_list/data/drift_shopping_trip_repository.dart';
import 'package:bipa/features/shopping_list/domain/finish_shopping_trip.dart';
import 'package:bipa/features/shopping_list/domain/shopping_list_item.dart';
import 'package:bipa/features/shopping_list/domain/shopping_list_repository.dart';
import 'package:bipa/features/shopping_list/domain/shopping_list_sections.dart';
import 'package:bipa/features/shopping_list/domain/shopping_trip.dart';
import 'package:bipa/features/stock/presentation/stock_providers.dart';
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

/// Histórico de preços dos produtos da lista.
final shoppingListHistoryProvider = StreamProvider.autoDispose<List<PriceHistoryEntry>>((ref) async* {
  // O ref não pode ser usado depois do await: o provider pode ter sido
  // reconstruído nesse meio-tempo.
  final prices = ref.watch(priceRepositoryProvider);
  final entries = await ref.watch(shoppingListProvider.future);
  final productIds = {for (final entry in entries) ?entry.item.productId};
  yield* prices.watchHistoryOfProducts(productIds);
});

/// Preço de referência dos produtos da lista, para estimar o total.
final shoppingListPricesProvider = Provider.autoDispose<AsyncValue<Map<String, Money>>>(
  (ref) => ref.watch(shoppingListHistoryProvider).whenData(referencePrices),
);

final shoppingListSummaryProvider = Provider.autoDispose<ShoppingListSummary>((ref) {
  final entries = ref.watch(shoppingListProvider).value ?? const [];
  final prices = ref.watch(shoppingListPricesProvider).value ?? const {};
  return ShoppingListSummary.of(entries, prices);
});

/// Produtos que ainda faltam comprar, para marcar "na lista" no Início.
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

final shoppingTripRepositoryProvider = Provider<ShoppingTripRepository>(
  (ref) => DriftShoppingTripRepository(
    ref.watch(appDatabaseProvider),
    ids: ref.watch(idGeneratorProvider),
    clock: ref.watch(clockProvider),
  ),
);

final finishShoppingTripProvider = Provider<FinishShoppingTrip>(
  (ref) => FinishShoppingTrip(
    trips: ref.watch(shoppingTripRepositoryProvider),
    list: ref.watch(shoppingListRepositoryProvider),
    stock: ref.watch(stockRepositoryProvider),
  ),
);

/// A compra em andamento, ou `null`.
final activeTripProvider = StreamProvider.autoDispose<ShoppingTrip?>(
  (ref) => ref.watch(shoppingTripRepositoryProvider).watchActive(),
);

/// O que a barra da compra mostra, ou `null` fora de uma compra.
final shoppingTripSummaryProvider = Provider.autoDispose<ShoppingTripSummary?>((ref) {
  final trip = ref.watch(activeTripProvider).value;
  // Sem a lista carregada, a barra mostraria "0 de 0 itens".
  final entries = ref.watch(shoppingListProvider).value;
  if (trip == null || entries == null) return null;
  final history = ref.watch(shoppingListHistoryProvider).value ?? const [];
  final marketId = trip.marketId;
  // O que foi registrado depois de começar a compra (no mercado dela, quando
  // ele é conhecido) é o que foi pago.
  final paid = history.where(
    (e) =>
        !e.observation.observedAt.isBefore(trip.startedAt) && (marketId == null || e.observation.marketId == marketId),
  );
  return ShoppingTripSummary.of(
    entries,
    tripPrices: referencePrices(paid),
    referencePrices: referencePrices(history),
  );
});

/// Nome do mercado da compra em andamento, quando ele foi detectado.
final activeTripMarketNameProvider = Provider.autoDispose<String?>((ref) {
  final marketId = ref.watch(activeTripProvider).value?.marketId;
  if (marketId == null) return null;
  final markets = ref.watch(marketsProvider).value ?? const [];
  return markets.where((m) => m.id == marketId).firstOrNull?.name;
});
