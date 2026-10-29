import 'package:bipa/core/money/money.dart';
import 'package:bipa/features/prices/domain/price_comparison.dart';
import 'package:bipa/features/prices/domain/price_observation.dart';
import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:bipa/features/products/domain/product_package.dart';
import 'package:bipa/features/products/domain/unit_price.dart';
import 'package:meta/meta.dart';

/// Um preço com a embalagem a que ele se refere e o preço por kg (ou L, ou
/// un) dela, para comparar tamanhos diferentes (ADR 0013).
@immutable
final class PackagePrice {
  const PackagePrice({required this.entry, this.package});

  final PriceHistoryEntry entry;

  /// Nula quando o preço é de um produto sem embalagem.
  final ProductPackage? package;

  Money get price => entry.observation.price;

  UnitPrice? get unitPrice => package?.unitPrice(price);

  @override
  bool operator ==(Object other) => other is PackagePrice && other.entry == entry && other.package == package;

  @override
  int get hashCode => Object.hash(entry, package);
}

/// O preço mais recente de cada embalagem (o menor entre os mercados), da
/// mais barata por kg para a mais cara. As da grandeza principal
/// ([mainPriceUnit]) vêm antes, e as sem tamanho vão para o fim, pelo preço.
List<PackagePrice> latestPricePerPackage(Iterable<PriceHistoryEntry> history, List<ProductPackage> packages) {
  final byId = {for (final package in packages) package.id: package};
  final byPackage = <String, List<PriceHistoryEntry>>{};
  for (final entry in history) {
    final packageId = entry.observation.packageId;
    if (packageId != null && byId.containsKey(packageId)) byPackage.putIfAbsent(packageId, () => []).add(entry);
  }
  return [
    for (final MapEntry(key: packageId, value: entries) in byPackage.entries)
      PackagePrice(entry: latestPricePerMarket(entries).first, package: byId[packageId]),
  ]..sort(_byUnitPrice(mainPriceUnit(history, packages)));
}

/// Em cada mercado, a embalagem mais barata por kg entre os preços mais
/// recentes de cada uma, do mercado mais barato para o mais caro. Na
/// grandeza principal ([mainPriceUnit]) primeiro: um mercado que só tem o
/// preço por kg fica depois dos que têm o por litro, quando a maioria é por
/// litro.
List<PackagePrice> bestPricePerMarket(Iterable<PriceHistoryEntry> history, List<ProductPackage> packages) {
  final byId = {for (final package in packages) package.id: package};
  final compare = _byUnitPrice(mainPriceUnit(history, packages));
  final byMarketAndPackage = <(String, String?), List<PriceHistoryEntry>>{};
  for (final entry in history) {
    final key = (entry.observation.marketId, entry.observation.packageId);
    byMarketAndPackage.putIfAbsent(key, () => []).add(entry);
  }
  final bestByMarket = <String, PackagePrice>{};
  for (final MapEntry(key: (marketId, packageId), value: entries) in byMarketAndPackage.entries) {
    final candidate = PackagePrice(entry: latestPricePerMarket(entries).first, package: byId[packageId]);
    final current = bestByMarket[marketId];
    if (current == null || compare(candidate, current) < 0) bestByMarket[marketId] = candidate;
  }
  return bestByMarket.values.toList()..sort(compare);
}

/// A grandeza em que os preços de um produto se comparam (G16): a unidade
/// base (kg, L ou un) da maioria dos preços com tamanho. Num empate, a da
/// embalagem mais recente entre as empatadas. `null` sem nenhum preço com
/// tamanho.
///
/// Um produto pode ter embalagens de grandezas diferentes (o leite em pó
/// movido para o "Leite"), e kg contra litro não tem resposta: o destaque e
/// o "Mais barato" ficam na grandeza principal.
MeasureUnit? mainPriceUnit(Iterable<PriceHistoryEntry> history, List<ProductPackage> packages) {
  final byId = {for (final package in packages) package.id: package};
  final counts = <MeasureUnit, int>{};
  final newest = <MeasureUnit, DateTime>{};
  for (final entry in history) {
    final package = byId[entry.observation.packageId];
    final unit = package?.unitPrice(entry.observation.price)?.unit;
    if (package == null || unit == null) continue;
    counts[unit] = (counts[unit] ?? 0) + 1;
    final current = newest[unit];
    if (current == null || package.createdAt.isAfter(current)) newest[unit] = package.createdAt;
  }
  MeasureUnit? main;
  for (final MapEntry(key: unit, value: count) in counts.entries) {
    final mainCount = counts[main] ?? 0;
    if (main == null || count > mainCount || (count == mainCount && newest[unit]!.isAfter(newest[main]!))) {
      main = unit;
    }
  }
  return main;
}

/// O primeiro de [prices], já em ordem, é o mais barato de alguma coisa: há
/// outro preço na mesma grandeza que ele (ou, sem tamanho, outro sem
/// tamanho) para comparar. Um kg sozinho entre preços por litro não é "Mais
/// barato" de nada.
bool firstIsCheapest(List<PackagePrice> prices) {
  final first = prices.firstOrNull;
  return first != null && prices.skip(1).any((other) => other.unitPrice?.unit == first.unitPrice?.unit);
}

/// Pelo preço por kg; sem ele, pelo preço, depois dos que têm. Preços de
/// grandezas diferentes (kg e L) não se comparam: os de [main] vêm primeiro,
/// e os outros ficam agrupados pela unidade, para a ordem ser sempre a mesma.
Comparator<PackagePrice> _byUnitPrice(MeasureUnit? main) => (a, b) {
  final aUnit = a.unitPrice;
  final bUnit = b.unitPrice;
  if (aUnit == null || bUnit == null) {
    if (aUnit != null) return -1;
    if (bUnit != null) return 1;
    return a.price.compareTo(b.price);
  }
  if (aUnit.unit != bUnit.unit) {
    if (aUnit.unit == main) return -1;
    if (bUnit.unit == main) return 1;
    return aUnit.unit.index.compareTo(bUnit.unit.index);
  }
  return aUnit.price.compareTo(bUnit.price);
};
