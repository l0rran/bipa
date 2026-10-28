import 'dart:async';

import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/core/location/location_service.dart';
import 'package:bipa/core/navigation/routes.dart';
import 'package:bipa/core/notifications/live_notification.dart';
import 'package:bipa/core/notifications/notifications_provider.dart';
import 'package:bipa/core/permissions/permission_access.dart';
import 'package:bipa/core/widgets/permission_rationale.dart';
import 'package:bipa/features/markets/presentation/markets_providers.dart';
import 'package:bipa/features/shopping_list/presentation/shopping_list_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// "Ir às compras": começa a compra, abre o modo carrinho (com a lista por
/// baixo) e, se a localização permitir, descobre em qual mercado a pessoa
/// está. O mercado escolhido no chip da lista vale mais que a localização.
Future<void> startShopping(BuildContext context, WidgetRef ref) async {
  // Tudo lido antes dos awaits: a tela pode sair da árvore no meio do caminho.
  final trips = ref.read(shoppingTripRepositoryProvider);
  final location = ref.read(locationServiceProvider);
  final markets = ref.read(marketRepositoryProvider);
  final finder = ref.read(nearestMarketFinderProvider);
  final chosenMarket = ref.read(listChosenMarketProvider.notifier);
  final chosen = ref.read(listChosenMarketProvider);
  final notifications = ref.read(liveNotificationsProvider);

  await _askPermissions(context, location, notifications, needsLocation: chosen == null);

  final trip = await trips.start(marketId: chosen);
  chosenMarket.clear();
  // A Lista fica por baixo: voltar do carrinho cai nela.
  if (context.mounted) {
    context.go(Routes.shoppingList);
    unawaited(context.push<void>(Routes.cartMode));
  }
  if (trip.marketId != null) return;
  // Sem pedir de novo: quem disse "Agora não" escolhe o mercado no carrinho.
  final position = await location.currentLocation(request: false);
  if (position is! LocationFound) return;
  final market = finder.marketAt(position.point, await markets.all());
  if (market != null) await trips.setMarket(trip.id, market.id);
}

/// As permissões da compra, com o motivo antes do pedido do sistema: a
/// localização acha o mercado (só quando nenhum foi escolhido) e a
/// notificação ao vivo acompanha a compra (ADR 0015). Tudo antes do
/// carrinho, para o pedido da câmera não atropelar estes.
Future<void> _askPermissions(
  BuildContext context,
  LocationService location,
  LiveNotifications notifications, {
  required bool needsLocation,
}) async {
  final l10n = AppLocalizations.of(context);
  final askLocation = needsLocation && await location.access() == PermissionAccess.askable;
  final askNotifications = await notifications.access() == PermissionAccess.askable;
  if (!askLocation && !askNotifications) return;
  if (!context.mounted) return;

  final explained = await explainPermission(
    context,
    icon: askLocation ? Icons.place_outlined : Icons.notifications_outlined,
    reason: switch ((askLocation, askNotifications)) {
      (true, true) => l10n.permissionShoppingBoth,
      (true, false) => l10n.permissionShoppingLocation,
      _ => l10n.permissionShoppingNotifications,
    },
  );
  if (!explained) return;
  if (askLocation) await location.requestAccess();
  if (askNotifications) await notifications.requestPermission();
}
