import 'package:bipa/core/money/money.dart';
import 'package:bipa/features/prices/domain/package_prices.dart';
import 'package:bipa/features/prices/domain/price_comparison.dart';
import 'package:bipa/features/prices/domain/price_observation.dart';
import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/products/domain/product_package.dart';

/// O preço que a linha do produto mostra na lista de Produtos.
///
/// Com [perUnit] nulo, é o preço da embalagem; com ele, é o preço por kg, litro
/// ou unidade, que serve para comparar embalagens de tamanhos diferentes.
/// [observedAt] é o dia em que esse preço foi visto, para a linha dizer a idade
/// de um preço velho (F5).
typedef HeadlinePrice = ({Money price, MeasureUnit? perUnit, DateTime observedAt});

/// Escolhe o único preço da linha de [product]:
///
/// - uma embalagem: o preço dela, o menor entre os mercados;
/// - várias: o menor preço por kg (ou litro, ou unidade) entre elas, porque o
///   preço de uma embalagem não diz nada sobre as outras;
/// - nenhuma, como no granel (ADR 0018): o menor preço sem embalagem, por kg.
///
/// Em cada caso vale o preço mais recente de cada mercado. Devolve `null` sem
/// preço (ou, com várias embalagens, sem tamanho para o preço por kg).
HeadlinePrice? headlinePrice({
  required Product product,
  required List<ProductPackage> packages,
  required Iterable<PriceHistoryEntry> history,
}) {
  switch (packages) {
    case []:
      final entries = history.where((entry) => entry.observation.packageId == null);
      final cheapest = latestPricePerMarket(entries).firstOrNull;
      return cheapest == null
          ? null
          : (
              price: cheapest.observation.price,
              perUnit: product.unit.baseUnit,
              observedAt: cheapest.observation.observedAt,
            );
    case [final only]:
      final entries = history.where((entry) => entry.observation.packageId == only.id);
      final cheapest = latestPricePerMarket(entries).firstOrNull;
      return cheapest == null
          ? null
          : (price: cheapest.observation.price, perUnit: null, observedAt: cheapest.observation.observedAt);
    default:
      final withUnit = [
        for (final entry in latestPricePerPackage(history, packages))
          if (entry.unitPrice case final unitPrice?)
            (unitPrice: unitPrice, observedAt: entry.entry.observation.observedAt),
      ];
      // Na unidade do produto, quando houver: kg e litro não se comparam.
      final best =
          withUnit.where((item) => item.unitPrice.unit == product.unit.baseUnit).firstOrNull ?? withUnit.firstOrNull;
      return best == null
          ? null
          : (price: best.unitPrice.price, perUnit: best.unitPrice.unit, observedAt: best.observedAt);
  }
}
