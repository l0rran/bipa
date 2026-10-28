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
  const ShoppingTripSummary({required this.done, required this.total, this.spent});

  /// [spent] é a soma do que vai ser levado no carrinho, com os preços lidos
  /// ou digitados: é um total real, sem estimativa ("≈"). Sem nenhum preço
  /// ainda, é `null`.
  factory ShoppingTripSummary.of(Iterable<ShoppingListEntry> entries, Iterable<CartEntry> cart) {
    var done = 0;
    var total = 0;
    for (final entry in entries) {
      total++;
      if (entry.item.isChecked) done++;
    }
    Money? spent;
    for (final entry in cart) {
      final subtotal = entry.item.subtotal;
      if (subtotal != null) spent = (spent ?? Money.zero) + subtotal;
    }
    return ShoppingTripSummary(done: done, total: total, spent: spent);
  }

  final int done;
  final int total;
  final Money? spent;

  double get progress => total == 0 ? 0 : done / total;

  @override
  bool operator ==(Object other) =>
      other is ShoppingTripSummary && other.done == done && other.total == total && other.spent == spent;

  @override
  int get hashCode => Object.hash(done, total, spent);
}
