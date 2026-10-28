import 'package:bipa/core/database/database_provider.dart';
import 'package:bipa/core/di/core_providers.dart';
import 'package:bipa/features/stock/data/drift_stock_repository.dart';
import 'package:bipa/features/stock/domain/stock_item.dart';
import 'package:bipa/features/stock/domain/stock_lot.dart';
import 'package:bipa/features/stock/domain/stock_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final stockRepositoryProvider = Provider<StockRepository>(
  (ref) => DriftStockRepository(
    ref.watch(appDatabaseProvider),
    ids: ref.watch(idGeneratorProvider),
    clock: ref.watch(clockProvider),
  ),
);

final stockProvider = StreamProvider.autoDispose<List<StockEntry>>(
  (ref) => ref.watch(stockRepositoryProvider).watchAll(),
);

/// Os lotes em casa de um produto, com as embalagens (ADR 0013).
final stockLotsProvider = StreamProvider.autoDispose.family<List<StockLot>, String>(
  (ref, productId) => ref.watch(stockRepositoryProvider).watchLots(productId),
);
