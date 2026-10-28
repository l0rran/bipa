import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/features/markets/presentation/market_picker_sheet.dart';
import 'package:bipa/features/shopping_list/presentation/cancel_shopping.dart';
import 'package:bipa/features/shopping_list/presentation/shopping_list_providers.dart';
import 'package:bipa/features/shopping_list/presentation/trip_review_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// "Terminei": mostra a folha "Fim da compra" e, confirmado, o comprado vai
/// para o estoque e sai da lista, com Desfazer; a folha também cancela a
/// compra. Usado na Lista, no modo carrinho e na notificação, onde a folha
/// também evita que um toque no bolso encerre a compra.
Future<void> finishShopping(BuildContext context, WidgetRef ref, String tripId) async {
  // Lidos antes do await: a tela pode fechar quando a compra terminar.
  final review = ref.read(reviewShoppingTripProvider);
  final finish = ref.read(finishShoppingTripProvider);
  final trips = ref.read(shoppingTripRepositoryProvider);
  final setMarket = ref.read(setTripMarketProvider);
  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppLocalizations.of(context);
  try {
    // Preços lidos sem mercado: é a última chance de guardá-los (ADR 0020),
    // venha o "Terminei" do carrinho, da Lista ou da notificação. Fechar a
    // escolha termina assim mesmo, sem eles.
    final trip = await trips.findActive();
    if (trip != null && trip.id == tripId && trip.marketId == null && await setMarket.pendingPrices(tripId) > 0) {
      if (!context.mounted) return;
      final market = await pickMarket(context, title: l10n.tripPendingMarketTitle);
      if (market != null) await setMarket(tripId, market.id);
      if (!context.mounted) return;
    }
    final summary = await review(tripId);
    if (summary == null || !context.mounted) return;
    switch (await showTripReview(context, summary)) {
      case null:
        return;
      case TripEnd.cancel:
        if (context.mounted) await cancelShopping(context, ref, tripId);
        return;
      case TripEnd.finish:
        break;
    }
    final finished = await finish(tripId);
    if (finished == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.tripFinished(finished.stocked.values.fold(0, (sum, count) => sum + count))),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: l10n.undo,
            onPressed: () async {
              try {
                await finish.undo(finished);
              } on Exception {
                messenger.showSnackBar(SnackBar(content: Text(l10n.tripFinishFailed)));
              }
            },
          ),
        ),
      );
  } on Exception {
    messenger.showSnackBar(SnackBar(content: Text(l10n.tripFinishFailed)));
  }
}
