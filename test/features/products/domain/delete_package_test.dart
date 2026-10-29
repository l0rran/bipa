import 'package:bipa/core/database/app_database.dart';
import 'package:bipa/core/money/money.dart';
import 'package:bipa/features/markets/data/drift_market_repository.dart';
import 'package:bipa/features/markets/domain/market.dart';
import 'package:bipa/features/prices/data/drift_price_repository.dart';
import 'package:bipa/features/prices/domain/price_observation.dart';
import 'package:bipa/features/prices/domain/price_source.dart';
import 'package:bipa/features/products/data/drift_product_repository.dart';
import 'package:bipa/features/products/domain/delete_package.dart';
import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/products/domain/product_package.dart';
import 'package:bipa/features/products/domain/product_repository.dart';
import 'package:bipa/features/shopping_list/data/drift_cart_repository.dart';
import 'package:bipa/features/shopping_list/data/drift_shopping_trip_repository.dart';
import 'package:bipa/features/stock/data/drift_stock_repository.dart';
import 'package:bipa/features/stock/domain/stock_movement_reason.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/test_database.dart';

void main() {
  final now = DateTime(2026, 10, 28, 9);
  late AppDatabase db;
  late DriftProductRepository products;
  late DriftStockRepository stock;
  late DeletePackage delete;

  setUp(() async {
    db = createTestDatabase();
    final ids = SequentialIdGenerator();
    products = DriftProductRepository(db, clock: () => now, ids: ids);
    stock = DriftStockRepository(db, ids: ids, clock: () => now);
    delete = DeletePackage(products: products);

    await products.save(
      Product(id: 'arroz', name: 'Arroz', unit: MeasureUnit.kilogram, createdAt: now, updatedAt: now),
    );
    await products.savePackage(
      ProductPackage(
        id: 'camil',
        productId: 'arroz',
        barcode: '7896006711155',
        size: 5,
        unit: MeasureUnit.kilogram,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await DriftMarketRepository(db).save(Market(id: 'm', name: 'Central', createdAt: now, updatedAt: now));
    await DriftPriceRepository(db).add(
      PriceObservation(
        id: 'preco',
        productId: 'arroz',
        packageId: 'camil',
        marketId: 'm',
        price: const Money.cents(2790),
        source: PriceSource.priceTag,
        observedAt: now,
        createdAt: now,
      ),
    );
    await stock.adjust(productId: 'arroz', delta: 1, reason: StockMovementReason.purchase, packageId: 'camil');
  });

  tearDown(() => db.close());

  test('apaga a embalagem e os preços dela; o desfazer devolve os dois e o lote', () async {
    final deleted = await delete('camil');

    expect(deleted.prices.map((p) => p.id), ['preco']);
    expect(await products.findPackageById('camil'), isNull);
    expect(await db.select(db.priceObservations).get(), isEmpty);
    expect((await stock.watchLots('arroz').first).single.packageId, isNull);

    await delete.undo(deleted);

    expect(await products.findPackageById('camil'), deleted.package);
    expect((await db.select(db.priceObservations).get()).single.priceCents, 2790);
    expect((await stock.watchLots('arroz').first).single.packageId, 'camil');
  });

  test('na compra em andamento, não apaga', () async {
    final ids = SequentialIdGenerator();
    final trip = await DriftShoppingTripRepository(db, ids: ids, clock: () => now).start();
    await DriftCartRepository(db, ids: ids, clock: () => now).addProduct(trip.id, 'arroz', packageId: 'camil');

    await expectLater(delete('camil'), throwsA(isA<PackageInOpenTripException>()));
    expect(await products.findPackageById('camil'), isNotNull);
  });

  test('o desfazer de um produto que foi apagado nesse meio-tempo não faz nada', () async {
    final deleted = await delete('camil');
    await products.delete('arroz');

    await delete.undo(deleted);

    expect(await products.findPackageById('camil'), isNull);
    expect(await db.select(db.priceObservations).get(), isEmpty);
  });
}
