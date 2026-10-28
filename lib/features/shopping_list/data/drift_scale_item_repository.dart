import 'package:bipa/core/database/app_database.dart';
import 'package:bipa/features/shopping_list/domain/scale_items.dart';

final class DriftScaleItemRepository implements ScaleItemRepository {
  const DriftScaleItemRepository(this._db);

  final AppDatabase _db;

  @override
  Future<String?> productIdFor(String marketId, String itemKey) async {
    final row = await (_db.select(_db.scaleItems)
          ..where((t) => t.marketId.equals(marketId) & t.itemKey.equals(itemKey)))
        .getSingleOrNull();
    return row?.productId;
  }

  /// Escolher outro produto para o mesmo código troca o lembrado.
  @override
  Future<void> remember(String marketId, String itemKey, String productId) async {
    await _db
        .into(_db.scaleItems)
        .insertOnConflictUpdate(ScaleItemsCompanion.insert(marketId: marketId, itemKey: itemKey, productId: productId));
  }
}
