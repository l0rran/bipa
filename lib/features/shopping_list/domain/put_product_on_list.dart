import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/shopping_list/domain/shopping_list_repository.dart';
import 'package:bipa/features/stock/domain/stock_repository.dart';

/// "Pôr na lista": o produto entra com o que falta para o "ter sempre"
/// (`StockItem.toBuy`), em vez de sempre 1. Com 1 leite em casa e "ter
/// sempre 4", entram 3.
final class PutProductOnList {
  const PutProductOnList({required ShoppingListRepository list, required StockRepository stock})
    : _list = list,
      _stock = stock;

  final ShoppingListRepository _list;
  final StockRepository _stock;

  Future<void> call(Product product) async {
    final item = await _stock.findByProduct(product.id);
    await _list.addProduct(productId: product.id, name: product.name, quantity: item?.toBuy ?? 1);
  }
}
