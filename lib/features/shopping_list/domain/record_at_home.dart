import 'package:bipa/core/transactions/unit_of_work.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/shopping_list/domain/put_product_on_list.dart';
import 'package:bipa/features/shopping_list/domain/shopping_list_item.dart';
import 'package:bipa/features/shopping_list/domain/shopping_list_repository.dart';
import 'package:bipa/features/stock/domain/stock_item.dart';
import 'package:bipa/features/stock/domain/stock_lot.dart';
import 'package:bipa/features/stock/domain/stock_movement_reason.dart';
import 'package:bipa/features/stock/domain/stock_repository.dart';
import 'package:meta/meta.dart';

/// O que mudou na lista junto com o estoque.
sealed class ListEffect {
  const ListEffect();
}

/// Nada mudou na lista.
final class ListUnchanged extends ListEffect {
  const ListUnchanged();
}

/// O produto saiu da lista (era o último que faltava comprar).
final class RemovedFromList extends ListEffect {
  const RemovedFromList(this.item);

  /// O item como estava, para o desfazer devolvê-lo.
  final ShoppingListItem item;
}

/// Faltava mais de um: a quantidade da lista diminuiu.
final class ListQuantityLowered extends ListEffect {
  const ListQuantityLowered({required this.itemId, required this.before});

  final String itemId;
  final int before;
}

/// O produto foi para a lista: ficou abaixo do "ter sempre".
final class AddedToList extends ListEffect {
  const AddedToList(this.productId);

  final String productId;
}

/// O que um bipe em casa mudou, para o desfazer.
@immutable
final class HomeChange {
  const HomeChange({required this.stock, this.list = const ListUnchanged()});

  final StockChange stock;
  final ListEffect list;
}

/// Caso de uso: os bipes em casa fecham o ciclo com a lista (modos "Comprei"
/// e "Dar baixa em casa" da câmera).
///
/// * "Comprei" soma uma embalagem e tira o produto da lista (ou diminui a
///   quantidade que falta, quando faltava mais de uma).
/// * "Usei" tira uma embalagem e, se o produto ficou abaixo do "ter sempre"
///   e não está na lista, põe nela com o que falta ([PutProductOnList]): é
///   bipar a embalagem vazia.
///
/// Estoque e lista mudam juntos, numa transação, e o [undo] volta os dois.
final class RecordAtHome {
  const RecordAtHome({
    required StockRepository stock,
    required ShoppingListRepository list,
    required PutProductOnList putOnList,
    required UnitOfWork work,
  }) : _stock = stock,
       _list = list,
       _putOnList = putOnList,
       _work = work;

  final StockRepository _stock;
  final ShoppingListRepository _list;
  final PutProductOnList _putOnList;
  final UnitOfWork _work;

  /// Uma embalagem a mais em casa. `null` se nada mudou.
  Future<HomeChange?> bought(Product product, {String? packageId}) async {
    // A lista é lida antes da transação, como em FinishShoppingTrip: os
    // streams ficam fora dela.
    final onList = (await _onList(product.id)).where((item) => !item.isChecked).firstOrNull;
    return _work.run(() async {
      final stock = await _stock.adjust(
        productId: product.id,
        packageId: packageId,
        delta: 1,
        reason: StockMovementReason.purchase,
      );
      if (stock.isEmpty) return null;
      if (onList == null) return HomeChange(stock: stock);
      if (onList.quantity > 1) {
        await _list.setQuantity(onList.id, onList.quantity - 1);
        return HomeChange(
          stock: stock,
          list: ListQuantityLowered(itemId: onList.id, before: onList.quantity),
        );
      }
      await _list.remove(onList.id);
      return HomeChange(stock: stock, list: RemovedFromList(onList));
    });
  }

  /// Uma embalagem a menos em casa. `null` se não havia o que tirar.
  Future<HomeChange?> used(Product product, {String? packageId}) async {
    // Na lista, mesmo marcado como comprado: o desfazer só tira o que este
    // bipe pôs.
    final alreadyOnList = (await _onList(product.id)).isNotEmpty;
    return _work.run(() async {
      final current = (await _stock.findByProduct(product.id))?.quantity ?? 0;
      final delta = StockItem.nextQuantity(current, -1) - current;
      if (delta == 0) return null;
      final stock = await _stock.adjust(
        productId: product.id,
        packageId: packageId,
        delta: delta,
        reason: StockMovementReason.consumption,
      );
      final item = await _stock.findByProduct(product.id);
      if (alreadyOnList || item == null || !item.isLow) return HomeChange(stock: stock);
      await _putOnList(product);
      return HomeChange(stock: stock, list: AddedToList(product.id));
    });
  }

  /// Volta o estoque e a lista como estavam antes do bipe.
  Future<void> undo(HomeChange change) => _work.run(() async {
    await _stock.revert(change.stock);
    switch (change.list) {
      case ListUnchanged():
        break;
      case RemovedFromList(:final item):
        await _list.restore(item);
      case ListQuantityLowered(:final itemId, :final before):
        await _list.setQuantity(itemId, before);
      case AddedToList(:final productId):
        await _list.removeProduct(productId);
    }
  });

  /// Os itens da lista deste produto.
  Future<List<ShoppingListItem>> _onList(String productId) async => [
    for (final entry in await _list.watchAll().first)
      if (entry.item.productId == productId) entry.item,
  ];
}
