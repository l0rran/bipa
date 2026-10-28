import 'package:bipa/core/database/database_provider.dart';
import 'package:bipa/core/location/geolocator_location_service.dart';
import 'package:bipa/core/location/location_service.dart';
import 'package:bipa/features/markets/data/drift_market_repository.dart';
import 'package:bipa/features/markets/domain/market.dart';
import 'package:bipa/features/markets/domain/market_repository.dart';
import 'package:bipa/features/markets/domain/nearest_market_finder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final marketRepositoryProvider = Provider<MarketRepository>(
  (ref) => DriftMarketRepository(ref.watch(appDatabaseProvider)),
);

final locationServiceProvider = Provider<LocationService>((ref) => const GeolocatorLocationService());

final nearestMarketFinderProvider = Provider<NearestMarketFinder>((ref) => const NearestMarketFinder());

final marketsProvider = StreamProvider.autoDispose<List<Market>>(
  (ref) => ref.watch(marketRepositoryProvider).watchAll(),
);

/// Posição atual do usuário. Use `ref.invalidate` para buscar de novo.
/// A posição atual, sem mostrar o pedido de permissão: abrir Mercados não
/// pergunta nada; a linha "Usar localização" explica e pede.
final currentLocationProvider = FutureProvider.autoDispose<LocationResult>(
  (ref) => ref.watch(locationServiceProvider).currentLocation(request: false),
);

/// Mercados ordenados pela distância até o usuário (ou por nome, se a
/// localização não estiver disponível).
final rankedMarketsProvider = Provider.autoDispose<AsyncValue<List<RankedMarket>>>((ref) {
  final markets = ref.watch(marketsProvider);
  final location = ref.watch(currentLocationProvider);
  final finder = ref.watch(nearestMarketFinderProvider);

  final position = switch (location) {
    AsyncData(value: LocationFound(:final point)) => point,
    _ => null,
  };

  return switch (markets) {
    AsyncData(:final value) => AsyncData(finder.rank(position, value)),
    AsyncError(:final error, :final stackTrace) => AsyncError(error, stackTrace),
    _ => const AsyncLoading(),
  };
});
