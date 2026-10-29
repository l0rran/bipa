import 'package:bipa/features/stock/domain/home_arrivals.dart';
import 'package:bipa/features/stock/domain/stock_item.dart';
import 'package:bipa/features/stock/domain/stock_location.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  StockItem item(String productId, {double quantity = 1}) => StockItem(
    productId: productId,
    quantity: quantity,
    location: StockLocation.pantry,
    updatedAt: DateTime(2026, 10, 28),
  );

  HomeArrivals arrivals(List<String> productIds) {
    final arrivals = HomeArrivals();
    productIds.forEach(arrivals.entered);
    return arrivals;
  }

  test('três produtos novos na sessão abrem a folha, na ordem em que entraram', () {
    final home = [item('arroz'), item('leite'), item('atum'), item('cafe')];

    expect(arrivals(['leite', 'arroz', 'atum']).toArrange(home), ['leite', 'arroz', 'atum']);
  });

  test('com menos de três produtos novos, a folha não aparece', () {
    final home = [item('arroz'), item('leite'), item('cafe')];

    expect(arrivals([]).toArrange(home), isEmpty);
    expect(arrivals(['leite', 'arroz']).toArrange(home), isEmpty);
  });

  test('o mesmo produto bipado de novo conta uma vez', () {
    final home = [item('arroz', quantity: 3), item('leite')];

    final session = arrivals(['arroz', 'arroz', 'leite', 'arroz']);

    expect(session.productIds, ['arroz', 'leite']);
    expect(session.toArrange(home), isEmpty);
  });

  test('o bipe desfeito deixa o item em zero e não conta', () {
    final home = [item('arroz'), item('leite', quantity: 0), item('atum'), item('cafe')];

    expect(arrivals(['arroz', 'leite', 'atum']).toArrange(home), isEmpty);
    expect(arrivals(['arroz', 'leite', 'atum', 'cafe']).toArrange(home), ['arroz', 'atum', 'cafe']);
  });

  test('o produto que saiu do estoque (apagado ou juntado) não conta', () {
    final home = [item('arroz'), item('atum')];

    expect(arrivals(['arroz', 'leite', 'atum']).toArrange(home), isEmpty);
  });

  test('o que já estava em casa não é registrado e não entra na conta', () {
    // A câmera só chama entered quando o item nasce no bipe; o café já
    // estava em casa e continua lá, mas fica de fora.
    final home = [item('arroz'), item('leite'), item('cafe', quantity: 5)];

    expect(arrivals(['arroz', 'leite']).toArrange(home), isEmpty);
  });
}
