import 'package:bipa/core/catalog/product_kind.dart';
import 'package:bipa/features/shopping_list/domain/aisle_order.dart';
import 'package:flutter_test/flutter_test.dart';

AislePick _pick(Aisle aisle, int minute) => (aisle: aisle, at: DateTime(2026, 10, 28, 10, minute));

void main() {
  test('sem compras, vale a ordem genérica, com "Outros" no fim', () {
    expect(AisleOrder.empty.sort([Aisle.other, Aisle.dairy, Aisle.produce]), [Aisle.produce, Aisle.dairy, Aisle.other]);
  });

  test('uma compra põe as seções visitadas na ordem em que foram percorridas', () {
    final order = AisleOrder.empty.learn([
      _pick(Aisle.grocery, 1),
      _pick(Aisle.grocery, 2),
      _pick(Aisle.produce, 3),
      _pick(Aisle.dairy, 4),
    ]);

    expect(order.sort([Aisle.produce, Aisle.dairy, Aisle.grocery, Aisle.drinks, Aisle.other]), [
      Aisle.grocery,
      Aisle.produce,
      Aisle.dairy,
      Aisle.drinks,
      Aisle.other,
    ]);
    expect(order.learned[Aisle.grocery], const LearnedAisle(position: 0, samples: 1));
  });

  test('uma compra fora do comum anda só metade do caminho', () {
    final learned = AisleOrder.empty.learn([_pick(Aisle.grocery, 1), _pick(Aisle.produce, 2)]);

    final next = learned.learn([_pick(Aisle.produce, 1), _pick(Aisle.grocery, 2)]);

    final produce = next.learned[Aisle.produce]!;
    expect(produce.samples, 2);
    // Metade do caminho entre onde estava e onde foi visto (o lugar da mercearia).
    final halfway = (learned.positionOf(Aisle.produce) + learned.positionOf(Aisle.grocery)) / 2;
    expect(produce.position, closeTo(halfway, 1e-9));
  });

  test('duas seções que trocaram de ordem e empataram voltam a se separar', () {
    final usual = [_pick(Aisle.cleaning, 1), _pick(Aisle.produce, 2)];
    var order = AisleOrder.empty.learn(usual);
    // Uma compra ao contrário: as duas andam metade do caminho e se encontram.
    order = order.learn([_pick(Aisle.produce, 1), _pick(Aisle.cleaning, 2)]);
    expect(order.positionOf(Aisle.cleaning), closeTo(order.positionOf(Aisle.produce), 1e-9));

    order = order.learn(usual);

    expect(order.sort([Aisle.produce, Aisle.cleaning]), [Aisle.cleaning, Aisle.produce]);
  });

  test('voltar para buscar algo esquecido não muda a ordem', () {
    final order = AisleOrder.empty.learn([
      _pick(Aisle.dairy, 1),
      _pick(Aisle.dairy, 2),
      _pick(Aisle.dairy, 3),
      _pick(Aisle.produce, 4),
      _pick(Aisle.dairy, 9),
    ]);

    expect(order.sort([Aisle.produce, Aisle.dairy]), [Aisle.dairy, Aisle.produce]);
  });

  test('uma seção só, ou só "Outros", não ensina nada', () {
    expect(AisleOrder.empty.learn([_pick(Aisle.dairy, 1), _pick(Aisle.dairy, 2)]), AisleOrder.empty);
    expect(AisleOrder.empty.learn([_pick(Aisle.dairy, 1), _pick(Aisle.other, 2)]), AisleOrder.empty);
  });
}
