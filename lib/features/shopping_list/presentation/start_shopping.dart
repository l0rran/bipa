import 'dart:async';

import 'package:bipa/core/location/location_service.dart';
import 'package:bipa/core/navigation/routes.dart';
import 'package:bipa/core/notifications/notifications_provider.dart';
import 'package:bipa/features/markets/presentation/markets_providers.dart';
import 'package:bipa/features/shopping_list/presentation/shopping_list_providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// "Ir às compras": começa a compra, abre a lista e, se a localização
/// permitir, descobre em qual mercado a pessoa está. O mercado escolhido no
/// chip da lista vale mais que a localização.
Future<void> startShopping(BuildContext context, WidgetRef ref) async {
  // Tudo lido antes dos awaits: a tela pode sair da árvore no meio do caminho.
  final trips = ref.read(shoppingTripRepositoryProvider);
  final location = ref.read(locationServiceProvider);
  final markets = ref.read(marketRepositoryProvider);
  final finder = ref.read(nearestMarketFinderProvider);
  final chosenMarket = ref.read(listChosenMarketProvider.notifier);
  final chosen = ref.read(listChosenMarketProvider);
  final notifications = ref.read(liveNotificationsProvider);

  final trip = await trips.start(marketId: chosen);
  chosenMarket.clear();
  if (context.mounted) context.go(Routes.shoppingList);
  try {
    if (trip.marketId != null) return;
    final position = await location.currentLocation();
    if (position is! LocationFound) return;
    final market = finder.marketAt(position.point, await markets.all());
    if (market != null) await trips.setMarket(trip.id, market.id);
  } finally {
    // A notificação ao vivo acompanha a compra (ADR 0015): o pedido de
    // permissão vem aqui, depois do da localização, para os dois não se
    // atropelarem.
    unawaited(notifications.requestPermission());
  }
}
