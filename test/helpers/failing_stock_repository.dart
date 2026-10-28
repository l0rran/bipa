import 'package:bipa/features/stock/domain/stock_item.dart';
import 'package:bipa/features/stock/domain/stock_location.dart';
import 'package:bipa/features/stock/domain/stock_lot.dart';
import 'package:bipa/features/stock/domain/stock_movement_reason.dart';
import 'package:bipa/features/stock/domain/stock_repository.dart';

/// Um estoque que lê normalmente e falha em toda escrita, como um banco
/// ocupado ou cheio.
final class FailingStockRepository implements StockRepository {
  const FailingStockRepository(this._reads);

  final StockRepository _reads;

  static Never _fail() => throw Exception('banco ocupado');

  @override
  Stream<List<StockEntry>> watchAll() => _reads.watchAll();

  @override
  Future<StockItem?> findByProduct(String productId) => _reads.findByProduct(productId);

  @override
  Stream<List<StockLot>> watchLots(String productId) => _reads.watchLots(productId);

  @override
  Future<StockChange> adjust({
    required String productId,
    required double delta,
    required StockMovementReason reason,
    String? packageId,
  }) async => _fail();

  @override
  Future<void> revert(StockChange change) async => _fail();

  @override
  Future<void> remove(String productId) async => _fail();

  @override
  Future<void> setTargetQuantity(String productId, double? target) async => _fail();

  @override
  Future<void> setLocation(String productId, StockLocation location) async => _fail();
}
