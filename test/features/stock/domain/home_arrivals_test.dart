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

  test('os produtos novos abrem a folha, na ordem em que entraram', () {
    final home = [item('arroz'), item('leite'), item('atum'), item('cafe')];

    expect(arrivals(['leite', 'arroz', 'atum']).toArrange(home), ['leite', 'arroz', 'atum']);
  });

  test('um só produto novo, sem o local conferido, já abre a folha (AB13)', () {
    final home = [item('atum'), item('cafe', quantity: 4)];
    final session = arrivals(['atum']);

    expect(session.mayArrange, isTrue);
    expect(session.toArrange(home), ['atum']);
  });

  test('o local escolhido no aviso tira o item da folha (AB13)', () {
    final home = [item('atum'), item('lasanha'), item('leite')];
    final session = arrivals(['atum', 'lasanha', 'leite'])..placeChosen('lasanha');

    expect(session.toArrange(home), ['atum', 'leite']);
  });

  test('com todos conferidos no aviso, nada sobra e a folha não abre (AB13)', () {
    final home = [item('atum'), item('lasanha')];
    final session = arrivals(['atum', 'lasanha'])
      ..placeChosen('atum')
      ..placeChosen('lasanha');

    expect(session.mayArrange, isFalse);
    expect(session.toArrange(home), isEmpty);
  });

  test('sem produto novo, a folha não abre', () {
    final home = [item('arroz'), item('leite')];
    final session = arrivals([]);

    expect(session.mayArrange, isFalse);
    expect(session.toArrange(home), isEmpty);
  });

  test('escolher o local de um produto que não entrou nesta sessão não muda nada', () {
    final home = [item('atum'), item('cafe')];
    final session = arrivals(['atum'])..placeChosen('cafe');

    expect(session.toArrange(home), ['atum']);
  });

  test('o item que nasce de novo volta a ter o local só sugerido', () {
    final home = [item('atum')];
    final session = arrivals(['atum'])
      ..placeChosen('atum')
      ..entered('atum');

    expect(session.toArrange(home), ['atum']);
  });

  test('o mesmo produto bipado de novo conta uma vez', () {
    final home = [item('arroz', quantity: 3), item('leite')];

    final session = arrivals(['arroz', 'arroz', 'leite', 'arroz']);

    expect(session.productIds, ['arroz', 'leite']);
    expect(session.toArrange(home), ['arroz', 'leite']);
  });

  test('o bipe desfeito deixa o item em zero e não conta', () {
    final home = [item('arroz'), item('leite', quantity: 0), item('atum')];

    expect(arrivals(['leite']).toArrange(home), isEmpty);
    expect(arrivals(['arroz', 'leite', 'atum']).toArrange(home), ['arroz', 'atum']);
  });

  test('o produto que saiu do estoque (apagado ou juntado) não conta', () {
    final home = [item('arroz'), item('atum')];

    expect(arrivals(['arroz', 'leite', 'atum']).toArrange(home), ['arroz', 'atum']);
  });

  test('o que já estava em casa não é registrado e não entra na conta', () {
    // A câmera só chama entered quando o item nasce no bipe; o café já
    // estava em casa e continua lá, mas fica de fora.
    final home = [item('arroz'), item('leite'), item('cafe', quantity: 5)];

    expect(arrivals(['arroz', 'leite']).toArrange(home), ['arroz', 'leite']);
  });
}
