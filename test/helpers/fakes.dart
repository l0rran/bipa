import 'package:bipa/core/id/id_generator.dart';
import 'package:bipa/features/prices/domain/market_price.dart';
import 'package:bipa/features/prices/domain/price_condition.dart';
import 'package:bipa/features/prices/domain/price_observation.dart';
import 'package:bipa/features/prices/domain/price_repository.dart';
import 'package:bipa/features/products/domain/deleted_package.dart';
import 'package:bipa/features/products/domain/moved_package.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/products/domain/product_package.dart';
import 'package:bipa/features/products/domain/product_repository.dart';

/// IDs previsíveis para asserções: `id-1`, `id-2`...
final class SequentialIdGenerator implements IdGenerator {
  var _next = 0;

  @override
  String newId() => 'id-${++_next}';
}

final class InMemoryProductRepository implements ProductRepository {
  final products = <String, Product>{};
  final packages = <String, ProductPackage>{};

  @override
  Stream<List<Product>> watchAll({String query = ''}) => Stream.value(products.values.toList());

  @override
  Stream<Product?> watchById(String id) => Stream.value(products[id]);

  @override
  Future<Product?> findById(String id) async => products[id];

  @override
  Future<Product?> findByBarcode(String barcode) async {
    final package = await findPackageByBarcode(barcode);
    return package == null ? null : products[package.productId];
  }

  @override
  Future<void> save(Product product) async {
    products[product.id] = product;
  }

  @override
  Stream<List<ProductPackage>> watchPackages(String productId) => Stream.value([
    for (final p in packages.values)
      if (p.productId == productId) p,
  ]);

  @override
  Stream<List<ProductPackage>> watchPackagesOfProducts(Set<String> productIds) => Stream.value([
    for (final p in packages.values)
      if (productIds.contains(p.productId)) p,
  ]);

  @override
  Future<ProductPackage?> findPackageById(String id) async => packages[id];

  @override
  Future<ProductPackage?> findPackageByBarcode(String barcode) async =>
      packages.values.where((p) => p.barcode == barcode).firstOrNull;

  @override
  Future<void> savePackage(ProductPackage package) async {
    packages[package.id] = package;
  }

  @override
  Future<void> delete(String id) async {
    products.remove(id);
    packages.removeWhere((_, p) => p.productId == id);
  }

  @override
  Future<void> merge({required String fromId, required String intoId}) async {
    for (final package in packages.values.where((p) => p.productId == fromId).toList()) {
      packages[package.id] = package.copyWith(productId: intoId);
    }
    products.remove(fromId);
  }

  @override
  Future<MovedPackage> movePackage({required String packageId, required String intoId}) async {
    final package = packages[packageId] ?? (throw const PackageNotFoundException());
    packages[packageId] = package.copyWith(productId: intoId);
    return MovedPackage(
      packageId: packageId,
      fromProductId: package.productId,
      intoProductId: intoId,
      createdStockItem: createsStockItem && package.productId != intoId,
    );
  }

  /// A próxima movida de embalagem diz que criou o item de estoque do destino.
  var createsStockItem = false;

  /// Produtos que, mesmo sem embalagem, ainda têm preço ou algo em casa.
  final productsWithData = <String>{};

  /// Os produtos de que `deleteEmptyStockItem` foi chamado.
  final emptyStockItemsDeleted = <String>[];

  @override
  Future<void> deleteEmptyStockItem(String productId) async {
    emptyStockItemsDeleted.add(productId);
  }

  @override
  Future<bool> isProductEmpty(String productId) async =>
      !productsWithData.contains(productId) && !packages.values.any((p) => p.productId == productId);

  @override
  Future<DeletedPackage> deletePackage(String packageId) async {
    final package = packages.remove(packageId) ?? (throw const PackageNotFoundException());
    return DeletedPackage(package: package);
  }

  @override
  Future<void> restorePackage(DeletedPackage deleted) async {
    packages[deleted.package.id] = deleted.package;
  }
}

final class InMemoryPriceRepository implements PriceRepository {
  final observations = <PriceObservation>[];

  @override
  Future<void> add(PriceObservation observation) async {
    observations.add(observation);
  }

  @override
  Future<void> addAll(Iterable<PriceObservation> observations) async {
    this.observations.addAll(observations);
  }

  @override
  Stream<List<PriceHistoryEntry>> watchHistory(String productId) => watchHistoryOfProducts({productId});

  @override
  Stream<List<PriceHistoryEntry>> watchHistoryOfProducts(Set<String> productIds) => Stream.value(
    withoutSuperseded([
      for (final o in observations.reversed)
        if (productIds.contains(o.productId)) PriceHistoryEntry(observation: o, marketName: o.marketId),
    ], (entry) => entry.observation),
  );

  @override
  Stream<Map<String, DateTime>> watchLatestPerMarket() {
    final latest = <String, DateTime>{};
    for (final o in observations) {
      final current = latest[o.marketId];
      if (current == null || o.observedAt.isAfter(current)) latest[o.marketId] = o.observedAt;
    }
    return Stream.value(latest);
  }

  @override
  Stream<List<MarketPrice>> watchLatestInMarket(String marketId) {
    final sorted =
        withoutSuperseded(
            observations,
            (o) => o,
          ).where((o) => o.marketId == marketId && o.condition is AnyCustomer).toList()
          ..sort((a, b) => b.observedAt.compareTo(a.observedAt));
    final latest = <(String, String?), MarketPrice>{};
    for (final o in sorted) {
      latest.putIfAbsent((o.productId, o.packageId), () => MarketPrice(observation: o, productName: o.productId));
    }
    return Stream.value(latest.values.toList());
  }
}
