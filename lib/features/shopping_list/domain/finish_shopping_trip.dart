import 'package:bipa/core/catalog/product_kind.dart';
import 'package:bipa/features/shopping_list/domain/aisle_order.dart';
import 'package:bipa/features/shopping_list/domain/cart_item.dart';
import 'package:bipa/features/shopping_list/domain/shopping_list_item.dart';
import 'package:bipa/features/shopping_list/domain/shopping_list_repository.dart';
import 'package:bipa/features/shopping_list/domain/shopping_trip.dart';
import 'package:bipa/features/stock/domain/stock_lot.dart';
import 'package:bipa/features/stock/domain/stock_movement_reason.dart';
import 'package:bipa/features/stock/domain/stock_repository.dart';
import 'package:meta/meta.dart';

/// O que o "Terminei" fez, para poder desfazer.
@immutable
final class FinishedShoppingTrip {
  const FinishedShoppingTrip({
    required this.tripId,
    required this.bought,
    required this.stocked,
    this.changes = const [],
    this.marketId,
    this.aisleOrderBefore,
  });

  final String tripId;

  /// Itens marcados na lista, que saíram dela.
  final List<ShoppingListItem> bought;

  /// Quantas unidades de cada produto entraram no estoque.
  final Map<String, int> stocked;

  /// O que cada entrada mudou no estoque, para o desfazer tirar exatamente
  /// os lotes que entraram (ADR 0013).
  final List<StockChange> changes;

  /// O mercado da compra e a ordem das seções que ele tinha antes de
  /// aprender com ela (ADR 0014); o desfazer volta para essa ordem.
  final String? marketId;
  final AisleOrder? aisleOrderBefore;
}

/// Caso de uso: termina a compra. Entra no estoque o que está no carrinho
/// para levar (na quantidade bipada) e o que foi marcado à mão na lista (uma
/// embalagem). O marcado sai da lista; o que faltou continua nela.
final class FinishShoppingTrip {
  FinishShoppingTrip({
    required ShoppingTripRepository trips,
    required ShoppingListRepository list,
    required CartRepository cart,
    required StockRepository stock,
    required AisleOrderRepository aisles,
  }) : _trips = trips,
       _list = list,
       _cart = cart,
       _stock = stock,
       _aisles = aisles;

  final ShoppingTripRepository _trips;
  final ShoppingListRepository _list;
  final CartRepository _cart;
  final StockRepository _stock;
  final AisleOrderRepository _aisles;

  /// Devolve `null` se a compra já não está em andamento (por exemplo, num
  /// segundo toque em "Terminei"), sem mexer no estoque de novo.
  Future<FinishedShoppingTrip?> call(String tripId) async {
    final active = await _trips.watchActive().first;
    if (active == null || active.id != tripId) return null;
    // Fecha a compra primeiro: um segundo "Terminei" já não passa da guarda.
    await _trips.finish(tripId);

    final cart = await _cart.watchTrip(tripId).first;
    final entries = await _list.watchAll().first;
    final bought = [
      for (final entry in entries)
        if (entry.item.isChecked) entry.item,
    ];

    // Cada embalagem do carrinho entra no estoque do seu produto; embalagens
    // diferentes do mesmo produto somam nele.
    final byPackage = <(String, String?), int>{};
    for (final entry in cart) {
      final quantity = entry.item.quantity;
      final key = (entry.item.productId, entry.item.packageId);
      if (entry.item.take) byPackage.update(key, (q) => q + quantity, ifAbsent: () => quantity);
    }
    // O que foi marcado à mão, sem passar pelo carrinho, entra com uma unidade.
    // O que está no carrinho sem "levar" não entra.
    final inCart = {for (final entry in cart) entry.item.productId};
    for (final item in bought) {
      final productId = item.productId;
      if (productId != null && !inCart.contains(productId)) byPackage[(productId, null)] = 1;
    }

    final stocked = <String, int>{};
    final changes = <StockChange>[];
    for (final MapEntry(key: (productId, packageId), value: quantity) in byPackage.entries) {
      changes.add(
        await _stock.adjust(
          productId: productId,
          packageId: packageId,
          delta: quantity.toDouble(),
          reason: StockMovementReason.purchase,
        ),
      );
      stocked.update(productId, (q) => q + quantity, ifAbsent: () => quantity);
    }
    final marketId = active.marketId;
    final aisleOrderBefore = marketId == null ? null : await _learnAisles(marketId, active, bought, cart);
    await _list.removeChecked();
    return FinishedShoppingTrip(
      tripId: tripId,
      bought: bought,
      stocked: stocked,
      changes: changes,
      marketId: marketId,
      aisleOrderBefore: aisleOrderBefore,
    );
  }

  /// Aprende a ordem das seções do mercado com o que foi marcado na lista e
  /// bipado no carrinho durante a compra (ADR 0014). Devolve a ordem de
  /// antes, para o desfazer.
  Future<AisleOrder> _learnAisles(
    String marketId,
    ShoppingTrip trip,
    List<ShoppingListItem> bought,
    List<CartEntry> cart,
  ) async {
    final picks = <AislePick>[
      for (final item in bought)
        if (item.checkedAt case final at? when !at.isBefore(trip.startedAt))
          (aisle: ProductKind.of(item.name).aisle, at: at),
    ];
    // O que foi bipado sem estar na lista entra pelo horário do bipe.
    final onList = {for (final item in bought) item.productId};
    for (final entry in cart) {
      if (!onList.contains(entry.product.id)) {
        picks.add((aisle: ProductKind.of(entry.product.name).aisle, at: entry.item.addedAt));
      }
    }
    final before = await _aisles.find(marketId);
    final learned = before.learn(picks);
    if (learned != before) await _aisles.save(marketId, learned);
    return before;
  }

  /// Desfaz o [call]: tira do estoque o que entrou, devolve os itens à lista
  /// e reabre a compra, se nenhuma outra tiver começado nesse meio-tempo.
  Future<void> undo(FinishedShoppingTrip finished) async {
    for (final change in finished.changes) {
      await _stock.revert(change);
    }
    for (final item in finished.bought) {
      await _list.restore(item);
    }
    if ((finished.marketId, finished.aisleOrderBefore) case (final marketId?, final before?)) {
      await _aisles.save(marketId, before);
    }
    await _trips.reopen(finished.tripId);
  }
}
