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
    'Peixe fresco': StockLocation.fridge,
    'Atum': StockLocation.pantry,
    'Atum em lata Gomes da Costa': StockLocation.pantry,
    'Sardinha 125 g': StockLocation.pantry,
    'Milho verde em lata': StockLocation.pantry,
    'Leite longa vida 1 L': StockLocation.pantry,
    'Leite integral caixinha': StockLocation.pantry,
    'Leite UHT desnatado': StockLocation.pantry,
    'Leite em pó Ninho': StockLocation.pantry,
    'Ovomaltine': StockLocation.pantry,
    'Achocolatado Nescau': StockLocation.pantry,
    'Sorvete de creme': StockLocation.freezer,
    'Lasanha congelada Sadia': StockLocation.freezer,
    'Frango congelado': StockLocation.freezer,
    'Pão de queijo congelado': StockLocation.freezer,
    'Hambúrguer bovino': StockLocation.freezer,
    'Lasanha à bolonhesa': StockLocation.pantry,
    'Cerveja lata 350 ml': StockLocation.pantry,
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
