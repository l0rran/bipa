import 'package:bipa/features/stock/domain/stock_location.dart';
import 'package:bipa/features/stock/domain/suggested_location.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const cases = {
    'Leite integral 1 L': StockLocation.fridge,
    'Iogurte natural': StockLocation.fridge,
    'Queijo mussarela': StockLocation.fridge,
    'Ovos brancos 12 un': StockLocation.fridge,
    'Frango resfriado': StockLocation.fridge,
    'Atum': StockLocation.fridge,
    'Sorvete de creme': StockLocation.freezer,
    'Sabão em pó': StockLocation.cleaning,
    'Detergente Ypê': StockLocation.cleaning,
    'Shampoo': StockLocation.bathroom,
    'Arroz 5 kg': StockLocation.pantry,
    'Leite condensado': StockLocation.pantry,
    'Pilhas AA': StockLocation.pantry,
    '': StockLocation.pantry,
  };

  cases.forEach((name, location) {
    test('"$name" nasce em ${location.label}', () => expect(suggestedLocation(name), location));
  });
}
