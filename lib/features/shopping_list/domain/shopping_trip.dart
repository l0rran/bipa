import 'package:bipa/core/money/money.dart';
import 'package:bipa/features/shopping_list/domain/cart_item.dart';
import 'package:bipa/features/shopping_list/domain/shopping_list_item.dart';
import 'package:meta/meta.dart';

/// Uma ida ao mercado (o modo compra): começa em "Ir às compras" e termina em
/// "Terminei". Privada, como a lista (ADR 0007).
@immutable
final class ShoppingTrip {
  const ShoppingTrip({required this.id, required this.startedAt, this.marketId, this.finishedAt});

  final String id;

  /// Mercado detectado pela localização, quando houver.
  final String? marketId;
  final DateTime startedAt;
  final DateTime? finishedAt;

  bool get isActive => finishedAt == null;

  @override
  bool operator ==(Object other) =>
      other is ShoppingTrip &&
      other.id == id &&
      other.marketId == marketId &&
      other.startedAt == startedAt &&
      other.finishedAt == finishedAt;

  @override
  int get hashCode => Object.hash(id, marketId, startedAt, finishedAt);
}

/// Acesso às idas ao mercado.
abstract interface class ShoppingTripRepository {
  /// A compra em andamento, ou `null`.
  Stream<ShoppingTrip?> watchActive();

  /// O mesmo que [watchActive], numa leitura só (dentro de uma transação).
  Future<ShoppingTrip?> findActive();

  /// Começa uma compra. Se já há uma em andamento, devolve ela.
  Future<ShoppingTrip> start({String? marketId});

  Future<void> setMarket(String tripId, String marketId);

  Future<void> finish(String tripId);

  /// Desiste da compra: ela e o carrinho dela somem, sem mexer no estoque.
  /// A lista fica como está.
  Future<void> cancel(String tripId);

  /// Desfaz o "Terminei". Não reabre se outra compra já começou.
  Future<void> reopen(String tripId);

  /// O mercado da compra mais recente que teve mercado, ou `null`: é o
  /// mercado que a lista mostra antes de "Ir às compras".
  Stream<String?> watchLastMarketId();
}

/// O que a barra da compra mostra: quantos itens da lista já foram e quanto
/// soma o carrinho.
@immutable
final class ShoppingTripSummary {
  const ShoppingTripSummary({
    required this.done,
    required this.total,
    this.spent,
    this.estimated = false,
    this.unpriced = 0,
    this.packages = 0,
  });

  /// [spent] é a soma do que vai ser levado no carrinho e do que foi
  /// marcado à mão na lista, pelo preço esperado ([expected], o preço de
  /// uma embalagem de cada produto), que deixa o total estimado. Sem preço,
  /// o marcado à mão conta em [unpriced] (CE4). Sem nenhum preço ainda, é
  /// `null`.
  ///
  /// Com [since] (o começo da compra), o item marcado antes dela e que não
  /// está no carrinho fica de fora da conta, como no "Terminei": não foi
  /// comprado agora, e também não falta.
  factory ShoppingTripSummary.of(
    Iterable<ShoppingListEntry> entries,
    Iterable<CartEntry> cart, {
    DateTime? since,
    Map<String, Money> expected = const {},
  }) {
    final taken = {
      for (final entry in cart)
        if (entry.item.take) entry.item.productId,
    };
    var done = 0;
    var total = 0;
    for (final entry in entries) {
      final item = entry.item;
      final before = since != null && item.isChecked && !item.isCheckedSince(since);
      if (before && !taken.contains(item.productId)) continue;
      total++;
      if (item.isChecked) done++;
    }
    Money? spent;
    var estimated = false;
    var unpriced = 0;
    var packages = 0;
    for (final entry in cart) {
      if (!entry.item.take) continue;
      packages += entry.item.quantity;
      final subtotal = entry.item.subtotal;
      if (subtotal == null) {
        unpriced++;
        continue;
      }
      spent = (spent ?? Money.zero) + subtotal;
      if (entry.item.priceEstimated) estimated = true;
    }
    // O marcado à mão, sem passar pelo carrinho, vai com a quantidade da
    // lista, como no "Terminei".
    final inCart = {for (final entry in cart) entry.item.productId};
    for (final ShoppingListEntry(:item) in entries) {
      if (!item.isChecked || (since != null && !item.isCheckedSince(since))) continue;
      if (inCart.contains(item.productId)) continue;
      final price = switch (item.productId) {
        final productId? => expected[productId],
        null => null,
      };
      if (price == null) {
        unpriced++;
      } else {
        spent = (spent ?? Money.zero) + price * item.quantity;
        estimated = true;
      }
    }
    return ShoppingTripSummary(
      done: done,
      total: total,
      spent: spent,
      estimated: estimated,
      unpriced: unpriced,
      packages: packages,
    );
  }

  final int done;
  final int total;
  final Money? spent;

  /// Algum preço do total ainda é o do histórico: o total leva "≈".
  final bool estimated;

  /// Itens que vão ser levados sem preço (no carrinho ou marcados à mão):
  /// ficam fora do total.
  final int unpriced;

  /// Embalagens no carrinho para levar: o que a barra diz numa compra sem
  /// lista, no lugar de "0 de 0".
  final int packages;

  /// A compra tem lista: o progresso é dela.
  bool get hasList => total > 0;

  double get progress => total == 0 ? 0 : done / total;

  @override
  bool operator ==(Object other) =>
      other is ShoppingTripSummary &&
      other.done == done &&
      other.total == total &&
      other.spent == spent &&
      other.estimated == estimated &&
      other.unpriced == unpriced &&
      other.packages == packages;

  @override
  int get hashCode => Object.hash(done, total, spent, estimated, unpriced, packages);
}
