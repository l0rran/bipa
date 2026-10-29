import 'package:bipa/core/database/app_database.dart';
import 'package:bipa/core/money/money.dart';
import 'package:bipa/features/markets/data/drift_market_repository.dart';
import 'package:bipa/features/markets/domain/market.dart';
import 'package:bipa/features/prices/data/drift_price_repository.dart';
import 'package:bipa/features/prices/domain/price_observation.dart';
import 'package:bipa/features/prices/domain/price_source.dart';
import 'package:bipa/features/products/data/drift_product_repository.dart';
import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/products/domain/product_package.dart';
import 'package:bipa/features/products/domain/product_repository.dart';
import 'package:bipa/features/shopping_list/data/drift_cart_repository.dart';
import 'package:bipa/features/shopping_list/data/drift_shopping_list_repository.dart';
import 'package:bipa/features/shopping_list/data/drift_shopping_trip_repository.dart';
import 'package:bipa/features/shopping_list/data/drift_trip_price_repository.dart';
import 'package:bipa/features/shopping_list/domain/trip_price.dart';
import 'package:bipa/features/stock/data/drift_stock_repository.dart';
import 'package:bipa/features/stock/domain/stock_location.dart';
import 'package:bipa/features/stock/domain/stock_movement_reason.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DriftProductRepository repository;
  final now = DateTime(2026, 10, 27);

  setUp(() {
    db = createTestDatabase();
    repository = DriftProductRepository(db);
  });

  tearDown(() => db.close());

  Product product(String id, String name) =>
      Product(id: id, name: name, unit: MeasureUnit.kilogram, createdAt: now, updatedAt: now);

  ProductPackage package(String id, String productId, {String? barcode, String? brand, double? size, int day = 1}) =>
      ProductPackage(
        id: id,
        productId: productId,
        barcode: barcode,
        brand: brand,
        size: size,
        unit: MeasureUnit.kilogram,
        createdAt: DateTime(2026, 10, day),
        updatedAt: DateTime(2026, 10, day),
      );

  test('salva e busca o produto por id e pelo código de uma embalagem', () async {
    final rice = product('arroz', 'Arroz branco');
    await repository.save(rice);
    await repository.savePackage(package('tio-joao', 'arroz', barcode: '7896006711155', brand: 'Tio João', size: 5));

    expect(await repository.findById('arroz'), rice);
    expect(await repository.findByBarcode('7896006711155'), rice);
    expect((await repository.findPackageByBarcode('7896006711155'))?.brand, 'Tio João');
    expect(await repository.findByBarcode('4006381333931'), isNull);
  });

  test('um produto tem várias embalagens, das mais novas para as mais antigas', () async {
    await repository.save(product('arroz', 'Arroz branco'));
    await repository.savePackage(package('tio-joao', 'arroz', brand: 'Tio João', size: 5, day: 1));
    await repository.savePackage(package('camil', 'arroz', brand: 'Camil', size: 10, day: 2));

    final packages = await repository.watchPackages('arroz').first;

    expect(packages.map((p) => p.label), ['Camil · 10 kg', 'Tio João · 5 kg']);
  });

  test('save atualiza um produto existente', () async {
    await repository.save(product('1', 'Cafe'));
    await repository.save(product('1', 'Café torrado'));

    final all = await repository.watchAll().first;
    expect(all.map((p) => p.name), ['Café torrado']);
  });

  test('impede o mesmo código de barras em duas embalagens', () async {
    await repository.save(product('cafe', 'Café'));
    await repository.save(product('outro', 'Outro'));
    await repository.savePackage(package('pilao', 'cafe', barcode: '7891910000197'));

    expect(
      () => repository.savePackage(package('outra', 'outro', barcode: '7891910000197')),
      throwsA(isA<DuplicateBarcodeException>()),
    );
  });

  test('embalagens sem código de barras não conflitam', () async {
    await repository.save(product('frutas', 'Banana'));
    await repository.savePackage(package('cacho', 'frutas'));
    await repository.savePackage(package('penca', 'frutas'));

    expect(await repository.watchPackages('frutas').first, hasLength(2));
  });

  test('watchAll ordena por nome e filtra por nome, marca ou código da embalagem', () async {
    await repository.save(product('1', 'feijão'));
    await repository.save(product('2', 'Arroz'));
    await repository.save(product('3', 'Café'));
    await repository.savePackage(package('a', '1', brand: 'Camil'));
    await repository.savePackage(package('b', '2', brand: 'Camil'));
    await repository.savePackage(package('c', '3', barcode: '7891910000197'));

    final all = await repository.watchAll().first;
    expect(all.map((p) => p.name), ['Arroz', 'Café', 'feijão']);

    final byBrand = await repository.watchAll(query: 'camil').first;
    expect(byBrand.map((p) => p.id), ['2', '1']);

    final byBarcode = await repository.watchAll(query: '7891910000197').first;
    expect(byBarcode.map((p) => p.id), ['3']);

    final byName = await repository.watchAll(query: 'arr').first;
    expect(byName.map((p) => p.id), ['2']);
  });

  test('juntar leva embalagens, preços, estoque e lista para o outro produto', () async {
    await repository.save(product('tio', 'Arroz Tio João'));
    await repository.save(product('arroz', 'Arroz branco'));
    await repository.savePackage(package('tio-5', 'tio', barcode: '7896006711155', brand: 'Tio João', size: 5));
    await repository.savePackage(package('camil-10', 'arroz', brand: 'Camil', size: 10));
    final stock = DriftStockRepository(db, ids: SequentialIdGenerator(), clock: () => now);
    await stock.adjust(productId: 'tio', delta: 1, reason: StockMovementReason.purchase);
    await stock.adjust(productId: 'arroz', delta: 2, reason: StockMovementReason.purchase);
    final list = DriftShoppingListRepository(db, ids: SequentialIdGenerator(), clock: () => now);
    await list.addProduct(productId: 'tio', name: 'Arroz Tio João');
    await list.addProduct(productId: 'arroz', name: 'Arroz branco');

    await repository.merge(fromId: 'tio', intoId: 'arroz');

    expect(await repository.findById('tio'), isNull);
    expect(await repository.findByBarcode('7896006711155'), product('arroz', 'Arroz branco'));
    expect((await repository.watchPackages('arroz').first).map((p) => p.id), unorderedEquals(['tio-5', 'camil-10']));
    expect((await stock.findByProduct('arroz'))?.quantity, 3);
    expect((await stock.watchLots('arroz').first).map((lot) => lot.packageId), unorderedEquals(['tio-5', 'camil-10']));
    expect((await list.watchAll().first).map((e) => e.item.productId), ['arroz']);
  });

  test('juntar leva o local lembrado só se o outro produto não tiver um (ADR 0021)', () async {
    await repository.save(product('tio', 'Arroz Tio João'));
    await repository.save(product('arroz', 'Arroz branco'));
    await repository.save(product('camil', 'Arroz Camil'));
    final stock = DriftStockRepository(db, ids: SequentialIdGenerator(), clock: () => now);
    await stock.setLocation('tio', StockLocation.cleaning);
    await stock.remove('tio');
    await stock.setLocation('camil', StockLocation.freezer);
    await stock.remove('camil');

    Future<List<(String, StockLocation)>> remembered() async => [
      for (final row in await db.select(db.rememberedLocations).get()) (row.productId, row.location),
    ];

    await repository.merge(fromId: 'tio', intoId: 'arroz');
    expect(await remembered(), unorderedEquals([('arroz', StockLocation.cleaning), ('camil', StockLocation.freezer)]));

    await repository.merge(fromId: 'arroz', intoId: 'camil');
    expect(await remembered(), [('camil', StockLocation.freezer)]);
  });

  test('juntar soma as linhas sem embalagem do carrinho, mantém a lista marcada e ressincroniza os preços', () async {
    await repository.save(product('tio', 'Arroz Tio João'));
    await repository.save(product('arroz', 'Arroz branco'));
    await DriftMarketRepository(db).save(Market(id: 'm', name: 'Central', createdAt: now, updatedAt: now));
    await DriftPriceRepository(db).add(
      PriceObservation(
        id: 'preco',
        productId: 'tio',
        marketId: 'm',
        price: const Money.cents(2790),
        source: PriceSource.priceTag,
        observedAt: now,
        createdAt: now,
      ),
    );
    await db.update(db.priceObservations).write(PriceObservationsCompanion(syncedAt: Value(now)));
    final ids = SequentialIdGenerator();
    final trip = await DriftShoppingTripRepository(db, ids: ids, clock: () => now).start();
    final cart = DriftCartRepository(db, ids: ids, clock: () => now);
    await cart.addProduct(trip.id, 'tio');
    await cart.addProduct(trip.id, 'arroz');
    await cart.addProduct(trip.id, 'arroz');
    final list = DriftShoppingListRepository(db, ids: ids, clock: () => now);
    await list.addProduct(productId: 'tio', name: 'Arroz Tio João');
    await list.addProduct(productId: 'arroz', name: 'Arroz branco');
    await list.checkProduct('tio');

    await repository.merge(fromId: 'tio', intoId: 'arroz');

    final items = await cart.watchTrip(trip.id).first;
    expect(items.map((e) => (e.item.productId, e.item.quantity)), [('arroz', 3)]);
    expect((await list.watchAll().first).single.item.isChecked, isTrue);
    final observation = await db.select(db.priceObservations).getSingle();
    expect(observation.productId, 'arroz');
    expect(observation.syncedAt, isNull);
  });

  test('apagar o produto leva junto embalagens, preços, estoque e lista', () async {
    await repository.save(product('arroz', 'Arroz branco'));
    await repository.savePackage(package('camil', 'arroz', barcode: '7896006711155'));
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
    final stock = DriftStockRepository(db, ids: SequentialIdGenerator(), clock: () => now);
    await stock.adjust(productId: 'arroz', delta: 1, reason: StockMovementReason.purchase);
    final list = DriftShoppingListRepository(db, ids: SequentialIdGenerator(), clock: () => now);
    await list.addProduct(productId: 'arroz', name: 'Arroz branco');

    await repository.delete('arroz');

    expect(await repository.findById('arroz'), isNull);
    expect(await repository.findPackageByBarcode('7896006711155'), isNull);
    expect(await db.select(db.priceObservations).get(), isEmpty);
    expect(await stock.findByProduct('arroz'), isNull);
    expect(await list.watchAll().first, isEmpty);
  });

  group('embalagem no produto errado (ADR 0022)', () {
    late DriftStockRepository stock;
    late DriftShoppingTripRepository trips;
    late DriftCartRepository cart;
    late DriftTripPriceRepository tripPrices;

    PriceObservation observation(String id, String productId, String packageId, int cents) => PriceObservation(
      id: id,
      productId: productId,
      packageId: packageId,
      marketId: 'm',
      price: Money.cents(cents),
      source: PriceSource.priceTag,
      observedAt: now,
      createdAt: now,
    );

    Future<PriceObservationRow> priceRow(String id) =>
        (db.select(db.priceObservations)..where((t) => t.id.equals(id))).getSingle();

    /// O Leite Ninho foi bipado no Leite integral, que também tem a Italac.
    setUp(() async {
      final ids = SequentialIdGenerator();
      repository = DriftProductRepository(db, clock: () => now, ids: ids);
      stock = DriftStockRepository(db, ids: ids, clock: () => now);
      trips = DriftShoppingTripRepository(db, ids: ids, clock: () => now);
      cart = DriftCartRepository(db, ids: ids, clock: () => now);
      tripPrices = DriftTripPriceRepository(db);

      await repository.save(product('integral', 'Leite integral'));
      await repository.save(product('ninho', 'Leite Ninho'));
      await repository.savePackage(package('ninho-400', 'integral', barcode: '7891000100101', brand: 'Ninho'));
      await repository.savePackage(package('italac', 'integral', barcode: '7898080640017', brand: 'Italac'));
      await DriftMarketRepository(db).save(Market(id: 'm', name: 'Central', createdAt: now, updatedAt: now));
      await DriftPriceRepository(db).addAll([
        observation('preco-ninho', 'integral', 'ninho-400', 1890),
        observation('preco-italac', 'integral', 'italac', 549),
      ]);
      await db.update(db.priceObservations).write(PriceObservationsCompanion(syncedAt: Value(now)));
      await stock.adjust(productId: 'integral', delta: 1, reason: StockMovementReason.purchase, packageId: 'ninho-400');
      await stock.adjust(productId: 'integral', delta: 2, reason: StockMovementReason.purchase, packageId: 'italac');
    });

    test('mover leva os preços, o estoque, o carrinho e o preço da compra', () async {
      // O Ninho já saiu de casa uma vez da Limpeza: volta a nascer ali (ADR 0021).
      await stock.setLocation('ninho', StockLocation.cleaning);
      await stock.remove('ninho');
      final trip = await trips.start(marketId: 'm');
      await cart.addProduct(trip.id, 'integral', packageId: 'ninho-400');
      await tripPrices.save(
        TripPrice(
          tripId: trip.id,
          productId: 'integral',
          packageId: 'ninho-400',
          price: const Money.cents(1890),
          source: PriceSource.priceTag,
          readAt: now,
          observationId: 'preco-ninho',
          marketId: 'm',
        ),
      );

      await repository.movePackage(packageId: 'ninho-400', intoId: 'ninho');

      final moved = await (db.select(db.productPackages)..where((t) => t.id.equals('ninho-400'))).getSingle();
      expect((moved.productId, moved.updatedAt, moved.syncedAt), ('ninho', now, null));
      expect((await repository.watchPackages('integral').first).map((p) => p.id), ['italac']);

      // A observação muda só de produto e volta para a fila; a outra fica.
      final ninhoPrice = await priceRow('preco-ninho');
      expect(
        (ninhoPrice.productId, ninhoPrice.packageId, ninhoPrice.priceCents, ninhoPrice.syncedAt),
        ('ninho', 'ninho-400', 1890, null),
      );
      final italacPrice = await priceRow('preco-italac');
      expect(italacPrice.productId, 'integral');
      expect(italacPrice.syncedAt, isNotNull);

      expect((await stock.findByProduct('integral'))?.quantity, 2);
      final ninhoItem = await stock.findByProduct('ninho');
      expect((ninhoItem?.quantity, ninhoItem?.location), (1, StockLocation.cleaning));
      expect((await stock.watchLots('ninho').first).map((lot) => lot.packageId), ['ninho-400']);
      expect((await stock.watchLots('integral').first).map((lot) => lot.packageId), ['italac']);
      final adjustments = await (db.select(
        db.stockMovements,
      )..where((t) => t.reason.equalsValue(StockMovementReason.adjustment))).get();
      expect(adjustments.map((m) => (m.productId, m.delta)), unorderedEquals([('integral', -1.0), ('ninho', 1.0)]));

      final items = await cart.watchTrip(trip.id).first;
      expect(items.map((e) => (e.item.productId, e.item.packageId)), [('ninho', 'ninho-400')]);
      final tripPrice = await tripPrices.find(trip.id, TripPrice.keyOf('ninho', 'ninho-400'));
      expect((tripPrice?.productId, tripPrice?.observationId), ('ninho', 'preco-ninho'));
    });

    test('mover para o produto em que ela já está não muda nada', () async {
      final before = await db.select(db.productPackages).get();

      await repository.movePackage(packageId: 'ninho-400', intoId: 'integral');

      expect(await db.select(db.productPackages).get(), before);
      expect((await priceRow('preco-ninho')).syncedAt, isNotNull);
      expect((await stock.findByProduct('integral'))?.quantity, 3);
    });

    test('a última embalagem pode sair: o produto fica, com o item em casa zerado', () async {
      await repository.movePackage(packageId: 'italac', intoId: 'ninho');
      await stock.setTargetQuantity('integral', 2);

      await repository.movePackage(packageId: 'ninho-400', intoId: 'ninho');

      expect(await repository.findById('integral'), isNotNull);
      expect(await repository.watchPackages('integral').first, isEmpty);
      final item = await stock.findByProduct('integral');
      expect((item?.quantity, item?.targetQuantity), (0, 2));
      expect((await stock.findByProduct('ninho'))?.quantity, 3);
    });

    test('o desfazer leva tudo de volta e o item de estoque que nasceu no destino sai', () async {
      final moved = await repository.movePackage(packageId: 'ninho-400', intoId: 'ninho');
      expect(moved.createdStockItem, isTrue);
      expect((moved.fromProductId, moved.intoProductId), ('integral', 'ninho'));

      await repository.movePackage(packageId: 'ninho-400', intoId: moved.fromProductId);
      await repository.deleteEmptyStockItem(moved.intoProductId);

      expect((await repository.findPackageById('ninho-400'))?.productId, 'integral');
      expect((await priceRow('preco-ninho')).productId, 'integral');
      expect((await stock.findByProduct('integral'))?.quantity, 3);
      expect(await stock.findByProduct('ninho'), isNull);
    });

    test('um destino que já estava em casa não perde o item no desfazer', () async {
      await stock.adjust(productId: 'ninho', delta: 1, reason: StockMovementReason.purchase);
      final moved = await repository.movePackage(packageId: 'ninho-400', intoId: 'ninho');
      expect(moved.createdStockItem, isFalse);

      await repository.movePackage(packageId: 'ninho-400', intoId: 'integral');
      await repository.deleteEmptyStockItem('ninho');

      expect((await stock.findByProduct('ninho'))?.quantity, 1);
    });

    test('um produto sem embalagem, preço e estoque está vazio; "ter sempre" ou preço o mantêm', () async {
      expect(await repository.isProductEmpty('integral'), isFalse);
      await repository.movePackage(packageId: 'italac', intoId: 'ninho');
      await repository.movePackage(packageId: 'ninho-400', intoId: 'ninho');
      // Sobra o item de estoque zerado, sem "ter sempre".
      expect(await repository.isProductEmpty('integral'), isTrue);

      await stock.setTargetQuantity('integral', 2);
      expect(await repository.isProductEmpty('integral'), isFalse);
    });

    test('mover uma embalagem que não existe avisa', () async {
      await expectLater(
        repository.movePackage(packageId: 'nenhuma', intoId: 'ninho'),
        throwsA(isA<PackageNotFoundException>()),
      );
    });

    test('apagar leva os preços, deixa em casa sem embalagem, e o desfazer devolve tudo', () async {
      // Uma compra terminada com o Ninho no carrinho.
      final trip = await trips.start(marketId: 'm');
      await cart.addProduct(trip.id, 'integral', packageId: 'ninho-400');
      await trips.finish(trip.id);
      final pricesBefore = await (db.select(db.priceObservations)..where((t) => t.id.equals('preco-ninho'))).get();

      final deleted = await repository.deletePackage('ninho-400');

      expect(await repository.findPackageById('ninho-400'), isNull);
      expect((await db.select(db.priceObservations).get()).map((p) => p.id), ['preco-italac']);
      expect((await stock.findByProduct('integral'))?.quantity, 3);
      expect(
        (await stock.watchLots('integral').first).map((lot) => (lot.packageId, lot.quantity)),
        unorderedEquals([(null, 1.0), ('italac', 2.0)]),
      );
      expect((await cart.watchTrip(trip.id).first).single.item.packageId, isNull);

      await repository.restorePackage(deleted);

      expect((await repository.findPackageById('ninho-400'))?.productId, 'integral');
      final restored = await (db.select(db.priceObservations)..where((t) => t.id.equals('preco-ninho'))).get();
      // Volta igual, mas pendente de sincronização.
      expect(
        restored.single.copyWith(syncedAt: const Value(null)),
        pricesBefore.single.copyWith(syncedAt: const Value(null)),
      );
      expect(
        (await stock.watchLots('integral').first).map((lot) => lot.packageId),
        unorderedEquals(['ninho-400', 'italac']),
      );
      expect((await cart.watchTrip(trip.id).first).single.item.packageId, 'ninho-400');
    });

    test('apagar a última embalagem deixa o produto', () async {
      await repository.deletePackage('ninho-400');
      await repository.deletePackage('italac');

      expect(await repository.findById('integral'), isNotNull);
      expect(await repository.watchPackages('integral').first, isEmpty);
      expect((await stock.findByProduct('integral'))?.quantity, 3);
    });

    test('não apaga a embalagem que está na compra em andamento', () async {
      final trip = await trips.start(marketId: 'm');
      await cart.addProduct(trip.id, 'integral', packageId: 'ninho-400');

      await expectLater(repository.deletePackage('ninho-400'), throwsA(isA<PackageInOpenTripException>()));

      expect(await repository.findPackageById('ninho-400'), isNotNull);
      expect(await db.select(db.priceObservations).get(), hasLength(2));
    });
  });
}
