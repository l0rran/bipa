import 'package:bipa/features/stock/domain/stock_item.dart';
import 'package:bipa/features/stock/domain/stock_location.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  StockItem item(double quantity, {double? target}) => StockItem(
    productId: 'arroz',
    quantity: quantity,
    targetQuantity: target,
    location: StockLocation.pantry,
    updatedAt: DateTime(2026),
  );

  test('nextQuantity nunca fica negativo', () {
    expect(StockItem.nextQuantity(2, -1), 1);
    expect(StockItem.nextQuantity(1, -3), 0);
    expect(StockItem.nextQuantity(0.5, 1), 1.5);
  });

  test('item zerado acabou', () {
    expect(item(0).isOut, isTrue);
    expect(item(0).isLow, isTrue);
    expect(item(0, target: 2).level, StockLevel.out);
  });

  test('item abaixo do ter sempre está acabando; no ter sempre, em dia', () {
    expect(item(1, target: 2).level, StockLevel.low);
    expect(item(2, target: 2).level, StockLevel.ok);
    expect(item(3, target: 2).isLow, isFalse);
    expect(item(3).isLow, isFalse);
  });

  test('toBuy sugere o que falta para o ter sempre, pelo menos 1', () {
    expect(item(1, target: 4).toBuy, 3);
    expect(item(1.5, target: 4).toBuy, 3);
    expect(item(4, target: 4).toBuy, 1);
    expect(item(0).toBuy, 1);
  });

  test('fillFraction mostra quanto do ter sempre está em casa', () {
    expect(item(2, target: 4).fillFraction, 0.5);
    expect(item(5, target: 4).fillFraction, 1);
    expect(item(0, target: 4).fillFraction, 0);
    expect(item(3).fillFraction, 1);
    expect(item(0).fillFraction, 0);
  });
}
