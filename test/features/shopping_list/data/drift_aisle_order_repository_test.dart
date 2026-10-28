import 'package:bipa/core/catalog/product_kind.dart';
import 'package:bipa/core/database/app_database.dart';
import 'package:bipa/features/markets/data/drift_market_repository.dart';
import 'package:bipa/features/markets/domain/market.dart';
import 'package:bipa/features/shopping_list/data/drift_aisle_order_repository.dart';
import 'package:bipa/features/shopping_list/domain/aisle_order.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DriftAisleOrderRepository repository;
  final now = DateTime(2026, 10, 28);

  setUp(() async {
    db = createTestDatabase();
    repository = DriftAisleOrderRepository(db);
    final markets = DriftMarketRepository(db);
    for (final id in ['vila', 'centro']) {
      await markets.save(Market(id: id, name: id, createdAt: now, updatedAt: now));
    }
  });

  tearDown(() => db.close());

  test('um mercado sem compras tem a ordem genérica', () async {
    expect(await repository.find('vila'), AisleOrder.empty);
  });

  test('guarda a ordem de cada mercado e troca a anterior', () async {
    const first = AisleOrder({
      Aisle.cleaning: LearnedAisle(position: 0, samples: 1),
      Aisle.produce: LearnedAisle(position: 0.7, samples: 1),
    });
    const second = AisleOrder({Aisle.dairy: LearnedAisle(position: 0.2, samples: 2)});

    await repository.save('vila', first);
    await repository.save('centro', second);
    await repository.save('vila', second);

    expect(await repository.find('vila'), second);
    expect(await repository.watch('centro').first, second);
  });

  test('apagar o mercado apaga a ordem dele', () async {
    await repository.save('vila', const AisleOrder({Aisle.dairy: LearnedAisle(position: 0.2, samples: 1)}));

    await (db.delete(db.markets)..where((t) => t.id.equals('vila'))).go();

    expect(await db.select(db.marketAisles).get(), isEmpty);
  });
}
