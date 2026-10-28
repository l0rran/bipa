import 'package:bipa/core/database/database_provider.dart';
import 'package:bipa/core/di/core_providers.dart';
import 'package:bipa/features/prices/data/drift_price_repository.dart';
import 'package:bipa/features/prices/data/mlkit_price_tag_reader.dart';
import 'package:bipa/features/prices/domain/price_observation.dart';
import 'package:bipa/features/prices/domain/price_repository.dart';
import 'package:bipa/features/prices/domain/price_tag.dart';
import 'package:bipa/features/prices/domain/register_price_observation.dart';
import 'package:bipa/features/products/presentation/products_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final priceRepositoryProvider = Provider<PriceRepository>(
  (ref) => DriftPriceRepository(ref.watch(appDatabaseProvider)),
);

/// Leitor de etiquetas. Mantenha-o observado (`ref.watch`) enquanto a tela
/// estiver aberta: ao ser descartado, os modelos do ML Kit são liberados.
final priceTagReaderProvider = Provider.autoDispose<PriceTagReader>((ref) {
  final reader = MlKitPriceTagReader();
  ref.onDispose(reader.close);
  return reader;
});

final registerPriceObservationProvider = Provider<RegisterPriceObservation>(
  (ref) => RegisterPriceObservation(
    products: ref.watch(productRepositoryProvider),
    prices: ref.watch(priceRepositoryProvider),
    ids: ref.watch(idGeneratorProvider),
    clock: ref.watch(clockProvider),
  ),
);

final priceHistoryProvider = StreamProvider.autoDispose.family<List<PriceHistoryEntry>, String>(
  (ref, productId) => ref.watch(priceRepositoryProvider).watchHistory(productId),
);

/// Quando foi o preço mais recente de cada mercado.
final latestPricePerMarketProvider = StreamProvider.autoDispose<Map<String, DateTime>>(
  (ref) => ref.watch(priceRepositoryProvider).watchLatestPerMarket(),
);
