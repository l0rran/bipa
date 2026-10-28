import 'package:bipa/core/camera/live_frame_analyzer.dart';
import 'package:bipa/core/catalog/product_kind.dart';
import 'package:bipa/core/database/database_provider.dart';
import 'package:bipa/core/di/core_providers.dart';
import 'package:bipa/features/markets/presentation/markets_providers.dart';
import 'package:bipa/features/prices/domain/list_cost.dart';
import 'package:bipa/features/prices/domain/price_comparison.dart';
import 'package:bipa/features/prices/domain/price_observation.dart';
import 'package:bipa/features/prices/presentation/prices_providers.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/products/domain/product_package.dart';
import 'package:bipa/features/products/presentation/products_providers.dart';
import 'package:bipa/features/shopping_list/data/drift_aisle_order_repository.dart';
import 'package:bipa/features/shopping_list/data/drift_cart_repository.dart';
import 'package:bipa/features/shopping_list/data/drift_scale_item_repository.dart';
import 'package:bipa/features/shopping_list/data/drift_shopping_list_repository.dart';
import 'package:bipa/features/shopping_list/data/drift_shopping_trip_repository.dart';
import 'package:bipa/features/shopping_list/data/drift_trip_price_repository.dart';
import 'package:bipa/features/shopping_list/data/mlkit_live_frame_analyzer.dart';
import 'package:bipa/features/shopping_list/domain/aisle_order.dart';
import 'package:bipa/features/shopping_list/domain/cancel_shopping_trip.dart';
import 'package:bipa/features/shopping_list/domain/cart_item.dart';
import 'package:bipa/features/shopping_list/domain/finish_shopping_trip.dart';
import 'package:bipa/features/shopping_list/domain/match_list_to_cart.dart';
import 'package:bipa/features/shopping_list/domain/put_product_on_list.dart';
import 'package:bipa/features/shopping_list/domain/record_at_home.dart';
import 'package:bipa/features/shopping_list/domain/record_trip_price.dart';
import 'package:bipa/features/shopping_list/domain/review_shopping_trip.dart';
import 'package:bipa/features/shopping_list/domain/scale_items.dart';
import 'package:bipa/features/shopping_list/domain/set_trip_market.dart';
import 'package:bipa/features/shopping_list/domain/shopping_list_item.dart';
import 'package:bipa/features/shopping_list/domain/shopping_list_repository.dart';
import 'package:bipa/features/shopping_list/domain/shopping_list_sections.dart';
import 'package:bipa/features/shopping_list/domain/shopping_trip.dart';
import 'package:bipa/features/shopping_list/domain/trip_price.dart';
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

/// O que falta na lista somado em cada mercado, do mais barato ao mais caro,
/// e qual é o mais barato de fato (tela de Mercados).
final listCostComparisonProvider = Provider.autoDispose<ListCostComparison>((ref) {
  final entries = ref.watch(shoppingListProvider).value ?? const [];
  final missing = {
    for (final entry in entries)
      if (!entry.item.isChecked) ?entry.item.productId,
  };
  final packages = ref.watch(listPackagesProvider).value ?? const [];
  return compareListCost(
    missing,
    ref.watch(shoppingListHistoryProvider).value ?? const [],
    packages: {for (final package in packages) package.id: package},
    // "3× Leite" custa três leites em cada mercado, como no total da lista.
    quantities: {
      for (final entry in entries)
        if (entry.item.productId case final productId? when !entry.item.isChecked) productId: entry.item.quantity,
    },
  );
});

/// As embalagens dos produtos da lista, para comparar pelo preço por kg.
final listPackagesProvider = StreamProvider.autoDispose<List<ProductPackage>>((ref) async* {
  // O ref não pode ser usado depois do await (como no histórico da lista).
  final products = ref.watch(productRepositoryProvider);
  final entries = await ref.watch(shoppingListProvider.future);
  yield* products.watchPackagesOfProducts({for (final entry in entries) ?entry.item.productId});
});

/// O preço de cada produto na lista: exato quando já foi visto no mercado
/// da lista, estimado pelos outros mercados quando não.
final shoppingListItemPricesProvider = Provider.autoDispose<Map<String, ListPrice>>(
  (ref) =>
      listPrices(ref.watch(shoppingListHistoryProvider).value ?? const [], marketId: ref.watch(listMarketIdProvider)),
);

/// O resumo da lista. O total soma os mesmos preços que as linhas mostram.
final shoppingListSummaryProvider = Provider.autoDispose<ShoppingListSummary>((ref) {
  final entries = ref.watch(shoppingListProvider).value ?? const [];
  final prices = ref.watch(shoppingListItemPricesProvider);
  return ShoppingListSummary.of(entries, {
    for (final MapEntry(key: productId, value: (:price, exact: _)) in prices.entries) productId: price,
  });
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

final cartRepositoryProvider = Provider<CartRepository>(
  (ref) => DriftCartRepository(
    ref.watch(appDatabaseProvider),
    ids: ref.watch(idGeneratorProvider),
    clock: ref.watch(clockProvider),
  ),
);

/// Cria o leitor de quadros do modo carrinho; quem cria fecha (ADR 0012).
final liveFrameAnalyzerFactoryProvider = Provider<LiveFrameAnalyzer Function()>((ref) => MlKitLiveFrameAnalyzer.new);

final aisleOrderRepositoryProvider = Provider<AisleOrderRepository>(
  (ref) => DriftAisleOrderRepository(ref.watch(appDatabaseProvider)),
);

/// O mercado escolhido no chip da lista, fora de uma compra; `null`
/// enquanto a pessoa não escolhe. Vale para a próxima compra só: o "Ir às
/// compras" usa e limpa.
final listChosenMarketProvider = NotifierProvider<ListChosenMarket, String?>(ListChosenMarket.new);

class ListChosenMarket extends Notifier<String?> {
  @override
  String? build() => null;

  void choose(String marketId) => state = marketId;

  void clear() => state = null;
}

/// O mercado da compra mais recente que teve mercado.
final lastMarketIdProvider = StreamProvider.autoDispose<String?>(
  (ref) => ref.watch(shoppingTripRepositoryProvider).watchLastMarketId(),
);

/// O mercado da lista: o da compra em andamento; fora dela, o escolhido no
/// chip ou, sem escolha, o da última compra.
final listMarketIdProvider = Provider.autoDispose<String?>((ref) {
  final trip = ref.watch(activeTripProvider).value;
  if (trip != null) return trip.marketId;
  return ref.watch(listChosenMarketProvider) ?? ref.watch(lastMarketIdProvider).value;
});

/// O nome do mercado da lista, quando há um.
final listMarketNameProvider = Provider.autoDispose<String?>((ref) {
  final marketId = ref.watch(listMarketIdProvider);
  if (marketId == null) return null;
  final markets = ref.watch(marketsProvider).value ?? const [];
  return markets.where((m) => m.id == marketId).firstOrNull?.name;
});

/// A ordem das seções aprendida num mercado (ADR 0014).
final marketAisleOrderProvider = StreamProvider.autoDispose.family<AisleOrder, String>(
  (ref, marketId) => ref.watch(aisleOrderRepositoryProvider).watch(marketId),
);

/// A ordem das seções no mercado da lista (ADR 0014); sem mercado, a
/// genérica.
final listAisleOrderProvider = StreamProvider.autoDispose<AisleOrder>((ref) {
  final marketId = ref.watch(listMarketIdProvider);
  return marketId == null ? Stream.value(AisleOrder.empty) : ref.watch(aisleOrderRepositoryProvider).watch(marketId);
});

/// Os códigos da balança lembrados em cada mercado (ADR 0018).
final scaleItemRepositoryProvider = Provider<ScaleItemRepository>(
  (ref) => DriftScaleItemRepository(ref.watch(appDatabaseProvider)),
);

/// Os produtos que a balança do mercado da compra já conhece: a linha deles
/// no carrinho troca o produto em vez da quantidade (D6).
final weighedProductIdsProvider = StreamProvider.autoDispose<Set<String>>((ref) {
  final marketId = ref.watch(activeTripProvider).value?.marketId;
  return marketId == null ? Stream.value(const {}) : ref.watch(scaleItemRepositoryProvider).watchProductIdsIn(marketId);
});

/// As etiquetas da balança no carrinho (ADR 0018).
final scaleItemsProvider = Provider<ScaleItems>(
  (ref) => ScaleItems(
    scale: ref.watch(scaleItemRepositoryProvider),
    products: ref.watch(productRepositoryProvider),
    cart: ref.watch(cartRepositoryProvider),
    createProduct: ref.watch(createProductByWeightProvider),
  ),
);

/// Marca o produto na lista quando o carrinho alcança a quantidade dela.
final matchListToCartProvider = Provider<MatchListToCart>(
  (ref) => MatchListToCart(list: ref.watch(shoppingListRepositoryProvider), cart: ref.watch(cartRepositoryProvider)),
);

/// Quantas embalagens de cada produto estão no carrinho para levar, na
/// compra em andamento ("1 de 3" na lista e na bandeja).
final takenInCartProvider = Provider.autoDispose<Map<String, int>>(
  (ref) => CartEntry.takenByProduct(ref.watch(activeCartProvider).value ?? const []),
);

/// "Pôr na lista" com o que falta para o "ter sempre".
final putProductOnListProvider = Provider<PutProductOnList>(
  (ref) => PutProductOnList(list: ref.watch(shoppingListRepositoryProvider), stock: ref.watch(stockRepositoryProvider)),
);

/// Os bipes em casa ("Comprei" e "Usei") que fecham o ciclo com a lista.
final recordAtHomeProvider = Provider<RecordAtHome>(
  (ref) => RecordAtHome(
    stock: ref.watch(stockRepositoryProvider),
    list: ref.watch(shoppingListRepositoryProvider),
    putOnList: ref.watch(putProductOnListProvider),
    work: ref.watch(unitOfWorkProvider),
  ),
);

final reviewShoppingTripProvider = Provider<ReviewShoppingTrip>(
  (ref) => ReviewShoppingTrip(
    trips: ref.watch(shoppingTripRepositoryProvider),
    list: ref.watch(shoppingListRepositoryProvider),
    cart: ref.watch(cartRepositoryProvider),
    prices: ref.watch(priceRepositoryProvider),
    products: ref.watch(productRepositoryProvider),
  ),
);

final finishShoppingTripProvider = Provider<FinishShoppingTrip>(
  (ref) => FinishShoppingTrip(
    trips: ref.watch(shoppingTripRepositoryProvider),
    list: ref.watch(shoppingListRepositoryProvider),
    cart: ref.watch(cartRepositoryProvider),
    stock: ref.watch(stockRepositoryProvider),
    aisles: ref.watch(aisleOrderRepositoryProvider),
    work: ref.watch(unitOfWorkProvider),
  ),
);

/// "Cancelar compra": o carrinho sai, e o marcado na compra volta a faltar.
final cancelShoppingTripProvider = Provider<CancelShoppingTrip>(
  (ref) => CancelShoppingTrip(
    trips: ref.watch(shoppingTripRepositoryProvider),
    list: ref.watch(shoppingListRepositoryProvider),
    work: ref.watch(unitOfWorkProvider),
  ),
);

/// Os preços de cada compra, guardados com ela (ADR 0020).
final tripPriceRepositoryProvider = Provider<TripPriceRepository>(
  (ref) => DriftTripPriceRepository(ref.watch(appDatabaseProvider)),
);

/// Guarda o preço lido ou digitado no carrinho, com ou sem mercado.
final recordTripPriceProvider = Provider<RecordTripPrice>(
  (ref) => RecordTripPrice(
    trips: ref.watch(shoppingTripRepositoryProvider),
    prices: ref.watch(tripPriceRepositoryProvider),
    register: ref.watch(registerPriceObservationProvider),
    work: ref.watch(unitOfWorkProvider),
    clock: ref.watch(clockProvider),
  ),
);

/// Muda o mercado da compra, gravando os preços que esperavam por ele.
final setTripMarketProvider = Provider<SetTripMarket>(
  (ref) => SetTripMarket(
    trips: ref.watch(shoppingTripRepositoryProvider),
    prices: ref.watch(tripPriceRepositoryProvider),
    register: ref.watch(registerPriceObservationProvider),
    work: ref.watch(unitOfWorkProvider),
  ),
);

/// A compra em andamento, ou `null`.
final activeTripProvider = StreamProvider.autoDispose<ShoppingTrip?>(
  (ref) => ref.watch(shoppingTripRepositoryProvider).watchActive(),
);

/// O carrinho da compra em andamento (vazio fora de uma compra).
final activeCartProvider = StreamProvider.autoDispose<List<CartEntry>>((ref) {
  final tripId = ref.watch(activeTripProvider).value?.id;
  return tripId == null ? Stream.value(const []) : ref.watch(cartRepositoryProvider).watchTrip(tripId);
});

/// O que a barra da compra mostra, ou `null` fora de uma compra.
final shoppingTripSummaryProvider = Provider.autoDispose<ShoppingTripSummary?>((ref) {
  final trip = ref.watch(activeTripProvider).value;
  // Sem a lista carregada, a barra mostraria "0 de 0 itens".
  final entries = ref.watch(shoppingListProvider).value;
  if (trip == null || entries == null) return null;
  // O marcado à mão entra no total pelo preço que a Lista mostra (CE4).
  final listed = ref.watch(shoppingListItemPricesProvider);
  return ShoppingTripSummary.of(
    entries,
    ref.watch(activeCartProvider).value ?? const [],
    since: trip.startedAt,
    expected: {for (final MapEntry(key: productId, value: (:price, exact: _)) in listed.entries) productId: price},
  );
});

/// Nome do mercado da compra em andamento, quando ele foi detectado.
final activeTripMarketNameProvider = Provider.autoDispose<String?>((ref) {
  final marketId = ref.watch(activeTripProvider).value?.marketId;
  if (marketId == null) return null;
  final markets = ref.watch(marketsProvider).value ?? const [];
  return markets.where((m) => m.id == marketId).firstOrNull?.name;
});

/// O que a notificação ao vivo mostra, ou `null` fora de uma compra
/// (ADR 0015): o progresso, o mercado e a próxima seção do percurso.
typedef LiveShopping = ({
  String tripId,
  ShoppingTripSummary summary,
  String? marketName,
  ({Aisle aisle, List<String> items})? next,
});

final liveShoppingProvider = Provider.autoDispose<LiveShopping?>((ref) {
  final trip = ref.watch(activeTripProvider).value;
  final summary = ref.watch(shoppingTripSummaryProvider);
  final entries = ref.watch(shoppingListProvider).value;
  if (trip == null || summary == null || entries == null) return null;
  final order = ref.watch(listAisleOrderProvider).value ?? AisleOrder.empty;
  return (
    tripId: trip.id,
    summary: summary,
    marketName: ref.watch(listMarketNameProvider),
    next: nextAisle(shoppingListSections(entries, order: order)),
  );
});
