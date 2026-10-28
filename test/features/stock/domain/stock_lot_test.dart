import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:bipa/features/products/domain/product_package.dart';
import 'package:bipa/features/stock/domain/stock_lot.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 10, 28);

StockLot _lot(double? size, MeasureUnit unit, double quantity) => StockLot(
  id: '$size$unit',
  productId: 'p',
  packageId: '$size$unit',
  package: ProductPackage(id: '$size$unit', productId: 'p', size: size, unit: unit, createdAt: _now, updatedAt: _now),
  quantity: quantity,
  since: _now,
);

StockLot _dated(String id, String? packageId, double quantity, int day) =>
    StockLot(id: id, productId: 'p', packageId: packageId, quantity: quantity, since: DateTime(2026, 10, day));

void main() {
  group('homeAmount', () {
    test('soma o tamanho dos lotes em casa', () {
      final lots = [_lot(5, MeasureUnit.kilogram, 1), _lot(10, MeasureUnit.kilogram, 1)];

      expect(homeAmount(lots), (amount: 15.0, unit: MeasureUnit.kilogram));
    });

    test('menos de 1 kg fica em gramas, misturando g e kg', () {
      final lots = [_lot(250, MeasureUnit.gram, 1), _lot(0.25, MeasureUnit.kilogram, 1)];

      expect(homeAmount(lots), (amount: 500.0, unit: MeasureUnit.gram));
    });

    test('sem tamanho, sem embalagem ou com grandezas diferentes, só a contagem vale', () {
      expect(homeAmount([_lot(null, MeasureUnit.kilogram, 1)]), isNull);
      expect(homeAmount([_lot(1, MeasureUnit.kilogram, 1), _lot(1, MeasureUnit.liter, 1)]), isNull);
      expect(homeAmount([_lot(5, MeasureUnit.kilogram, 1), _dated('solto', null, 1, 1)]), isNull);
      expect(homeAmount(const []), isNull);
    });
  });

  group('takeFromLots', () {
    test('tira do lote mais antigo primeiro', () {
      final lots = [_dated('b', 'camil', 1, 2), _dated('a', 'camil', 1, 1)];

      final plan = takeFromLots(lots, 1.5);

      expect(plan.map((p) => (p.lot.id, p.taken)), [('a', 1.0), ('b', 0.5)]);
    });

    test('com a embalagem informada, tira dela antes', () {
      final lots = [_dated('a', 'tio-joao', 1, 1), _dated('b', 'camil', 1, 2)];

      final plan = takeFromLots(lots, 1, packageId: 'camil');

      expect(plan.map((p) => (p.lot.id, p.taken)), [('b', 1.0)]);
    });

    test('não tira mais do que há', () {
      final plan = takeFromLots([_dated('a', null, 1, 1)], 3);

      expect(plan.map((p) => (p.lot.id, p.taken)), [('a', 1.0)]);
    });
  });

  test('a mudança soma o que cada lote mudou', () {
    final change = StockChange(
      productId: 'p',
      lots: [
        StockLotDelta(lotId: 'a', delta: -1, since: _now),
        StockLotDelta(lotId: 'b', delta: -0.5, since: _now),
      ],
    );

    expect(change.applied, -1.5);
    expect(const StockChange(productId: 'p').isEmpty, isTrue);
  });
}
