import 'package:bipa/core/money/money.dart';
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

  /// Começa uma compra. Se já há uma em andamento, devolve ela.
  Future<ShoppingTrip> start({String? marketId});

  Future<void> setMarket(String tripId, String marketId);

  Future<void> finish(String tripId);

  /// Desfaz o "Terminei". Não reabre se outra compra já começou.
  Future<void> reopen(String tripId);
}

/// O que a barra da compra mostra: quantos itens já foram e quanto custaram.
@immutable
final class ShoppingTripSummary {
  const ShoppingTripSummary({required this.done, required this.total, this.spent, this.estimated = false});

  /// Soma os itens marcados: o preço registrado durante a compra ([tripPrices])
  /// ou, sem ele, o preço de referência ([referencePrices]). Nesse caso, ou se
  /// algum item marcado não tem preço nenhum, o total é uma estimativa.
  factory ShoppingTripSummary.of(
    Iterable<ShoppingListEntry> entries, {
    required Map<String, Money> tripPrices,
    required Map<String, Money> referencePrices,
  }) {
    var done = 0;
    var total = 0;
    var estimated = false;
    Money? spent;
    for (final entry in entries) {
      total++;
      if (!entry.item.isChecked) continue;
      done++;
      final productId = entry.item.productId;
      final paid = productId == null ? null : tripPrices[productId];
      final reference = productId == null ? null : referencePrices[productId];
      final price = paid ?? reference;
      if (paid == null) estimated = true;
      if (price != null) spent = (spent ?? Money.zero) + price;
    }
    return ShoppingTripSummary(done: done, total: total, spent: spent, estimated: estimated);
  }

  final int done;
  final int total;
  final Money? spent;
  final bool estimated;

  double get progress => total == 0 ? 0 : done / total;

  @override
  bool operator ==(Object other) =>
      other is ShoppingTripSummary &&
      other.done == done &&
      other.total == total &&
      other.spent == spent &&
      other.estimated == estimated;

  @override
  int get hashCode => Object.hash(done, total, spent, estimated);
}
