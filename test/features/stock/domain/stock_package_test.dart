import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:bipa/features/products/domain/product_package.dart';
import 'package:bipa/features/stock/domain/stock_package.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 10, 28);

StockPackageCount _count(double? size, MeasureUnit unit, double quantity) => StockPackageCount(
  package: ProductPackage(id: '$size$unit', productId: 'p', size: size, unit: unit, createdAt: _now, updatedAt: _now),
  quantity: quantity,
  since: _now,
);

void main() {
  test('soma o tamanho das embalagens em casa', () {
    final counts = [_count(5, MeasureUnit.kilogram, 1), _count(10, MeasureUnit.kilogram, 1)];

    expect(homeAmount(counts, quantity: 2), (amount: 15.0, unit: MeasureUnit.kilogram));
  });

  test('menos de 1 kg fica em gramas, misturando g e kg', () {
    final counts = [_count(250, MeasureUnit.gram, 1), _count(0.25, MeasureUnit.kilogram, 1)];

    expect(homeAmount(counts, quantity: 2), (amount: 500.0, unit: MeasureUnit.gram));
  });

  test('sem tamanho, com grandezas diferentes ou com embalagens não contadas, só a contagem vale', () {
    expect(homeAmount([_count(null, MeasureUnit.kilogram, 1)], quantity: 1), isNull);
    expect(homeAmount([_count(1, MeasureUnit.kilogram, 1), _count(1, MeasureUnit.liter, 1)], quantity: 2), isNull);
    expect(homeAmount([_count(5, MeasureUnit.kilogram, 1)], quantity: 3), isNull);
    expect(homeAmount(const [], quantity: 0), isNull);
  });
}
