import 'package:bipa/core/database/app_database.dart';
import 'package:bipa/core/database/drift_unit_of_work.dart';
import 'package:bipa/core/money/money.dart';
import 'package:bipa/features/markets/data/drift_market_repository.dart';
import 'package:bipa/features/markets/domain/market.dart';
import 'package:bipa/features/prices/data/drift_price_repository.dart';
import 'package:bipa/features/prices/domain/price_condition.dart';
import 'package:bipa/features/prices/domain/price_source.dart';
import 'package:bipa/features/prices/domain/price_tag.dart';
import 'package:bipa/features/prices/domain/register_price_observation.dart';
import 'package:bipa/features/products/data/drift_product_repository.dart';
import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/products/domain/product_package.dart';
import 'package:bipa/features/shopping_list/data/drift_cart_repository.dart';
import 'package:bipa/features/shopping_list/data/drift_shopping_trip_repository.dart';
import 'package:bipa/features/shopping_list/data/drift_trip_price_repository.dart';
import 'package:bipa/features/shopping_list/domain/record_trip_price.dart';
import 'package:bipa/features/shopping_list/domain/set_trip_market.dart';
import 'package:bipa/features/shopping_list/domain/trip_price.dart';
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DriftShoppingTripRepository trips;
  late DriftTripPriceRepository tripPrices;
  late RecordTripPrice record;
  late SetTripMarket setMarket;
  late DateTime now;

  /// As observações gravadas, na ordem: (mercado, centavos, a que corrige).
  Future<List<(String, int, String?)>> observations() async => [
    for (final row in await (db.select(
      db.priceObservations,
    )..orderBy([(t) => OrderingTerm.asc(t.createdAt), (t) => OrderingTerm.asc(t.id)])).get())
      (row.marketId, row.priceCents, row.supersedesId),
  ];

  Future<bool> readTag(String tripId, int cents, {List<PriceOffer> otherOffers = const []}) => record(
    tripId: tripId,
    productId: 'cafe',
    price: Money.cents(cents),
    source: PriceSource.priceTag,
    otherOffers: otherOffers,
  );

  setUp(() async {
    now = DateTime(2026, 10, 28, 9);
    db = createTestDatabase();
    final ids = SequentialIdGenerator();
    DateTime clock() => now;
    trips = DriftShoppingTripRepository(db, ids: ids, clock: clock);
    tripPrices = DriftTripPriceRepository(db);
    final register = RegisterPriceObservation(
      products: DriftProductRepository(db),
      prices: DriftPriceRepository(db),
      ids: ids,
      clock: clock,
    );
    final work = DriftUnitOfWork(db);
    record = RecordTripPrice(trips: trips, prices: tripPrices, register: register, work: work, clock: clock);
    setMarket = SetTripMarket(trips: trips, prices: tripPrices, register: register, work: work);

    final products = DriftProductRepository(db);
    for (final (id, name) in [('cafe', 'Café'), ('arroz', 'Arroz')]) {
      await products.save(Product(id: id, name: name, unit: MeasureUnit.unit, createdAt: now, updatedAt: now));
    }
    await products.save(
      Product(id: 'tomate', name: 'Tomate italiano', unit: MeasureUnit.kilogram, createdAt: now, updatedAt: now),
    );
    // O mesmo tomate também vem em bandeja de 500 g, com código.
    await products.savePackage(
      ProductPackage(
        id: 'bandeja',
        productId: 'tomate',
        barcode: '7891000100103',
        size: 500,
        unit: MeasureUnit.gram,
        createdAt: now,
        updatedAt: now,
      ),
    );
    final markets = DriftMarketRepository(db);
    for (final (id, name) in [('vila', 'Vila'), ('assai', 'Assaí'), ('centro', 'Centro')]) {
      await markets.save(Market(id: id, name: name, createdAt: now, updatedAt: now));
    }
  });

  tearDown(() => db.close());

  test('com mercado, grava na hora; a mesma etiqueta não repete, e digitar corrige', () async {
    final trip = await trips.start(marketId: 'vila');

    expect(await readTag(trip.id, 2190), isTrue);
    expect(await readTag(trip.id, 2190), isFalse);
    final first = (await tripPrices.ofTrip(trip.id)).single.observationId;

    await record(tripId: trip.id, productId: 'cafe', price: const Money.cents(2790), source: PriceSource.manual);

    expect(await observations(), [('vila', 2190, null), ('vila', 2790, first)]);
    expect((await tripPrices.ofTrip(trip.id)).single.price, const Money.cents(2790));
  });

  test('sem mercado, espera com a compra e vai para o mercado escolhido com a hora da leitura', () async {
    final trip = await trips.start();
    final readAt = now;
    await readTag(
      trip.id,
      1899,
      otherOffers: const [PriceOffer(price: Money.cents(1799), condition: LoyaltyMembers())],
    );

    expect(await observations(), isEmpty);
    expect(await setMarket.pendingPrices(trip.id), 1);

    now = now.add(const Duration(minutes: 30));
    await setMarket(trip.id, 'vila');

    expect(await observations(), [('vila', 1899, null), ('vila', 1799, null)]);
    final saved = await db.select(db.priceObservations).get();
    expect(saved.map((row) => row.observedAt).toSet(), {readAt});
    expect(await setMarket.pendingPrices(trip.id), 0);
    expect((await trips.findActive())?.marketId, 'vila');
  });

  test('trocar o mercado leva os preços já gravados quando pedido, corrigindo os do anterior', () async {
    final trip = await trips.start(marketId: 'vila');
    await readTag(trip.id, 2190);
    final before = (await tripPrices.ofTrip(trip.id)).single.observationId;

    expect(await setMarket.recordedPrices(trip.id), 1);
    await setMarket(trip.id, 'assai', movePrices: true);

    expect(await observations(), [('vila', 2190, null), ('assai', 2190, before)]);
    final moved = (await tripPrices.ofTrip(trip.id)).single;
    expect(moved.observationId, isNot(before));
  });

  test('sem pedir, os preços gravados ficam no mercado anterior e os novos vão para o novo', () async {
    final trip = await trips.start(marketId: 'vila');
    await readTag(trip.id, 2190);

    await setMarket(trip.id, 'assai');
    await record(tripId: trip.id, productId: 'cafe', price: const Money.cents(2390), source: PriceSource.manual);

    // O digitado no Assaí não corrige o preço que ficou na Vila.
    expect(await observations(), [('vila', 2190, null), ('assai', 2390, null)]);
  });

  test('a mesma etiqueta lida no mercado novo é gravada nele', () async {
    final trip = await trips.start(marketId: 'vila');
    await readTag(trip.id, 2190);
    await setMarket(trip.id, 'assai');

    expect(await readTag(trip.id, 2190), isTrue);
    expect(await observations(), [('vila', 2190, null), ('assai', 2190, null)]);
  });

  test('fora da compra em andamento, nada é gravado', () async {
    final trip = await trips.start(marketId: 'vila');
    await trips.finish(trip.id);

    expect(await readTag(trip.id, 2190), isFalse);
    expect(await observations(), isEmpty);
  });

  test('a mesma etiqueta lida errado de novo não desfaz o preço digitado', () async {
    final trip = await trips.start(marketId: 'vila');
    await readTag(trip.id, 2190);
    await record(tripId: trip.id, productId: 'cafe', price: const Money.cents(2790), source: PriceSource.manual);
    final typed = (await tripPrices.ofTrip(trip.id)).single.observationId;

    expect(await readTag(trip.id, 2190), isFalse);
    expect((await tripPrices.ofTrip(trip.id)).single.observationId, typed);
    expect(await observations(), hasLength(2));
  });

  test('levar os preços leva só os do mercado que está sendo trocado', () async {
    final trip = await trips.start(marketId: 'vila');
    await readTag(trip.id, 2190);
    // Duas lojas: o café fica na Vila, e o arroz é lido no Assaí.
    await setMarket(trip.id, 'assai');
    await record(tripId: trip.id, productId: 'arroz', price: const Money.cents(2790), source: PriceSource.priceTag);

    expect(await setMarket.recordedPrices(trip.id), 1);
    await setMarket(trip.id, 'centro', movePrices: true);

    final saved = await observations();
    expect(saved.map((o) => (o.$1, o.$2)), [('vila', 2190), ('assai', 2790), ('centro', 2790)]);
    final byProduct = {for (final price in await tripPrices.ofTrip(trip.id)) price.productId: price.marketId};
    expect(byProduct, {'cafe': 'vila', 'arroz': 'centro'});
  });

  test('escolher de novo o mesmo mercado grava o que ainda esperava por ele', () async {
    final trip = await trips.start();
    await readTag(trip.id, 1899);
    // O mercado chegou por fora do caso de uso (como a localização fazia).
    await trips.setMarket(trip.id, 'vila');

    await setMarket(trip.id, 'vila');

    expect(await observations(), [('vila', 1899, null)]);
    expect(await setMarket.pendingPrices(trip.id), 0);
  });

  group('valor da pesagem e do granel (D8)', () {
    Future<bool> readPerKilo(String tripId) => record(
      tripId: tripId,
      productId: 'tomate',
      price: const Money.cents(899),
      source: PriceSource.priceTag,
      perKilo: true,
    );

    Future<bool> typeWeighing(String tripId) =>
        record(tripId: tripId, productId: 'tomate', price: const Money.cents(1240), source: PriceSource.manual);

    test('o valor digitado no granel fica só no carrinho; o preço por quilo continua', () async {
      final trip = await trips.start(marketId: 'vila');
      await readPerKilo(trip.id);

      expect(await typeWeighing(trip.id), isFalse);

      // O tomate segue a R$ 8,99 o quilo no histórico, e não a R$ 12,40.
      expect(await observations(), [('vila', 899, null)]);
      expect((await tripPrices.ofTrip(trip.id)).single.perKilo, isTrue);
    });

    test('corrigir o valor de uma etiqueta da balança não grava nada', () async {
      // A pesagem entra no carrinho sem preço guardado com a compra (ADR
      // 0018); digitar o valor certo, duas vezes, também não guarda.
      final trip = await trips.start(marketId: 'vila');

      expect(await typeWeighing(trip.id), isFalse);
      expect(
        await record(tripId: trip.id, productId: 'tomate', price: const Money.cents(1310), source: PriceSource.manual),
        isFalse,
      );

      expect(await observations(), isEmpty);
      expect(await tripPrices.ofTrip(trip.id), isEmpty);
    });

    test('sem mercado, não fica pendente, e escolher o mercado depois grava só o preço por quilo', () async {
      final trip = await trips.start();
      await readPerKilo(trip.id);
      await typeWeighing(trip.id);

      expect(await setMarket.pendingPrices(trip.id), 1);
      await setMarket(trip.id, 'vila');

      expect(await observations(), [('vila', 899, null)]);
      expect(await setMarket.pendingPrices(trip.id), 0);
    });

    test('a linha com embalagem continua indo para o histórico, e digitar corrige a etiqueta', () async {
      final trip = await trips.start(marketId: 'vila');
      Future<bool> price(int cents, PriceSource source) =>
          record(tripId: trip.id, productId: 'tomate', packageId: 'bandeja', price: Money.cents(cents), source: source);

      await price(899, PriceSource.priceTag);
      final read = (await tripPrices.ofTrip(trip.id)).single.observationId;
      expect(await price(999, PriceSource.manual), isTrue);

      expect(await observations(), [('vila', 899, null), ('vila', 999, read)]);
    });

    test('digitado numa embalagem sem etiqueta lida, também vai para o histórico', () async {
      final trip = await trips.start();
      await record(
        tripId: trip.id,
        productId: 'tomate',
        packageId: 'bandeja',
        price: const Money.cents(999),
        source: PriceSource.manual,
      );

      expect(await setMarket.pendingPrices(trip.id), 1);
      await setMarket(trip.id, 'vila');
      expect(await observations(), [('vila', 999, null)]);
    });

    test('a linha sem embalagem com etiqueta de gôndola é preço do produto, e digitar a corrige', () async {
      // A etiqueta sem código cujo produto foi escolhido pelo nome.
      final trip = await trips.start(marketId: 'vila');
      await readTag(trip.id, 2190);
      final read = (await tripPrices.ofTrip(trip.id)).single.observationId;

      expect(
        await record(tripId: trip.id, productId: 'cafe', price: const Money.cents(2790), source: PriceSource.manual),
        isTrue,
      );
      expect(
        await record(tripId: trip.id, productId: 'cafe', price: const Money.cents(2890), source: PriceSource.manual),
        isTrue,
      );

      final saved = await observations();
      expect(saved.map((o) => (o.$2, o.$3 != null)), [(2190, false), (2790, true), (2890, true)]);
      expect(saved[1].$3, read);
    });

    test('a regra da linha', () {
      final shelf = TripPrice(
        tripId: 't',
        productId: 'cafe',
        price: const Money.cents(2190),
        source: PriceSource.priceTag,
        readAt: DateTime(2026, 10, 28),
      );

      expect(isWeighingLine(packageId: null, shelfPrice: null), isTrue);
      expect(isWeighingLine(packageId: null, shelfPrice: shelf), isFalse);
      expect(isWeighingLine(packageId: 'pacote', shelfPrice: null), isFalse);
    });
  });

  test('o preço por quilo do granel é a estimativa da linha que espera a pesagem, até ela ter preço', () async {
    final trip = await trips.start(marketId: 'vila');
    final cart = DriftCartRepository(db, ids: SequentialIdGenerator(), clock: () => now);
    // O granel na bandeja, sem preço, e o café com o preço já firmado.
    await cart.addProduct(trip.id, 'arroz');
    await cart.addProduct(trip.id, 'cafe', price: const Money.cents(1899));
    final prices = tripPrices.watchTrip(trip.id);
    for (final (productId, cents) in [('arroz', 899), ('cafe', 3990)]) {
      await record(
        tripId: trip.id,
        productId: productId,
        price: Money.cents(cents),
        source: PriceSource.priceTag,
        perKilo: true,
      );
    }

    // Só o que espera a pesagem ganha a estimativa.
    expect(perKiloEstimates(await cart.watchTrip(trip.id).first, await prices.first), {
      'arroz:': const Money.cents(899),
    });

    // A pesagem (ou o preço digitado) firma a linha, e a estimativa sai.
    final line = (await cart.watchTrip(trip.id).first).firstWhere((entry) => entry.item.productId == 'arroz');
    await cart.setPrice(line.item.id, const Money.cents(1350));
    expect(perKiloEstimates(await cart.watchTrip(trip.id).first, await prices.first), isEmpty);
  });
}
