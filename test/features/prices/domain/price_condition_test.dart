import 'package:bipa/features/prices/domain/price_condition.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reconstrói cada condição a partir das colunas do banco', () {
    for (final condition in const [
      AnyCustomer(),
      LoyaltyMembers(),
      Wholesale(minimumQuantity: 6),
      Wholesale(),
    ]) {
      final minimum = condition is Wholesale ? condition.minimumQuantity : null;
      expect(PriceCondition.from(condition.kind, minimumQuantity: minimum), condition);
    }
  });

  test('atacados com mínimos diferentes são condições diferentes', () {
    expect(const Wholesale(minimumQuantity: 6), isNot(const Wholesale(minimumQuantity: 10)));
    expect(const Wholesale(minimumQuantity: 6), const Wholesale(minimumQuantity: 6));
  });
}
