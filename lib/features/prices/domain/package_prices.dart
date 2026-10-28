import 'package:bipa/core/money/money.dart';
import 'package:bipa/features/prices/domain/price_comparison.dart';
import 'package:bipa/features/prices/domain/price_observation.dart';
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
/// mais barata por kg para a mais cara. Embalagens sem tamanho vão para o fim,
/// pelo preço.
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
  ]..sort(_byUnitPrice);
}

/// Em cada mercado, a embalagem mais barata por kg entre os preços mais
/// recentes de cada uma, do mercado mais barato para o mais caro.
List<PackagePrice> bestPricePerMarket(Iterable<PriceHistoryEntry> history, List<ProductPackage> packages) {
  final byId = {for (final package in packages) package.id: package};
  final byMarketAndPackage = <(String, String?), List<PriceHistoryEntry>>{};
  for (final entry in history) {
    final key = (entry.observation.marketId, entry.observation.packageId);
    byMarketAndPackage.putIfAbsent(key, () => []).add(entry);
  }
  final bestByMarket = <String, PackagePrice>{};
  for (final MapEntry(key: (marketId, packageId), value: entries) in byMarketAndPackage.entries) {
    final candidate = PackagePrice(entry: latestPricePerMarket(entries).first, package: byId[packageId]);
    final current = bestByMarket[marketId];
    if (current == null || _byUnitPrice(candidate, current) < 0) bestByMarket[marketId] = candidate;
  }
  return bestByMarket.values.toList()..sort(_byUnitPrice);
}

/// Pelo preço por kg; sem ele, pelo preço, depois dos que têm.
int _byUnitPrice(PackagePrice a, PackagePrice b) {
  final aUnit = a.unitPrice;
  final bUnit = b.unitPrice;
  if (aUnit != null && bUnit != null && aUnit.unit == bUnit.unit) return aUnit.price.compareTo(bUnit.price);
  if (aUnit != null && bUnit == null) return -1;
  if (aUnit == null && bUnit != null) return 1;
  return a.price.compareTo(b.price);
}
