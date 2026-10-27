import 'package:bipa/core/id/id_generator.dart';
import 'package:bipa/features/prices/domain/price_observation.dart';
import 'package:bipa/features/prices/domain/price_repository.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/products/domain/product_repository.dart';

/// IDs previsíveis para asserções: `id-1`, `id-2`...
final class SequentialIdGenerator implements IdGenerator {
  var _next = 0;

  @override
  String newId() => 'id-${++_next}';
}

final class InMemoryProductRepository implements ProductRepository {
  final products = <String, Product>{};

  @override
  Stream<List<Product>> watchAll({String query = ''}) =>
      Stream.value(products.values.toList());

  @override
  Stream<Product?> watchById(String id) => Stream.value(products[id]);

  @override
  Future<Product?> findById(String id) async => products[id];

  @override
  Future<Product?> findByBarcode(String barcode) async =>
      products.values.where((p) => p.barcode == barcode).firstOrNull;

  @override
  Future<void> save(Product product) async {
    products[product.id] = product;
  }
}

final class InMemoryPriceRepository implements PriceRepository {
  final observations = <PriceObservation>[];

  @override
  Future<void> add(PriceObservation observation) async {
    observations.add(observation);
  }

  @override
  Stream<List<PriceHistoryEntry>> watchHistory(String productId) => Stream.value([
    for (final o in observations.reversed)
      if (o.productId == productId) PriceHistoryEntry(observation: o, marketName: o.marketId),
  ]);
}
