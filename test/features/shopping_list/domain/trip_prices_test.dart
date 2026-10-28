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
import 'package:bipa/features/shopping_list/data/drift_shopping_trip_repository.dart';
import 'package:bipa/features/shopping_list/data/drift_trip_price_repository.dart';
import 'package:bipa/features/shopping_list/domain/record_trip_price.dart';
import 'package:bipa/features/shopping_list/domain/set_trip_market.dart';
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

    await DriftProductRepository(
      db,
    ).save(Product(id: 'cafe', name: 'Café', unit: MeasureUnit.unit, createdAt: now, updatedAt: now));
    final markets = DriftMarketRepository(db);
    for (final (id, name) in [('vila', 'Vila'), ('assai', 'Assaí')]) {
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
}
