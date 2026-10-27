import 'package:bipa/features/stock/domain/stock_item.dart';
import 'package:bipa/features/stock/domain/stock_location.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  StockItem item(double quantity, {double? minimum}) => StockItem(
    productId: 'arroz',
    quantity: quantity,
    minimumQuantity: minimum,
    location: StockLocation.pantry,
    updatedAt: DateTime(2026),
  );

  test('nextQuantity nunca fica negativo', () {
    expect(StockItem.nextQuantity(2, -1), 1);
    expect(StockItem.nextQuantity(1, -3), 0);
    expect(StockItem.nextQuantity(0.5, 1), 1.5);
  });

  test('item zerado está em falta e acabando', () {
    expect(item(0).isOut, isTrue);
    expect(item(0).isLow, isTrue);
  });

  test('item no mínimo ou abaixo está acabando', () {
    expect(item(2, minimum: 2).isLow, isTrue);
    expect(item(3, minimum: 2).isLow, isFalse);
    expect(item(3).isLow, isFalse);
  });
}
