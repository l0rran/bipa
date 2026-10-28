import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/features/markets/domain/market.dart';
import 'package:bipa/features/shopping_list/domain/shopping_trip.dart';
import 'package:bipa/features/shopping_list/presentation/shopping_list_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Passa a compra para o [market] escolhido no chip (no carrinho ou na
/// Lista). Os preços que esperavam um mercado vão para ele. Se a compra já
/// tinha preços gravados em outro mercado, pergunta se eles vão junto (ADR
/// 0020): leva quem começou no mercado errado; deixa quem foi a duas lojas.
///
/// Fechar a pergunta sem responder não muda nada.
Future<void> changeTripMarket(BuildContext context, WidgetRef ref, ShoppingTrip trip, Market market) async {
  if (market.id == trip.marketId) return;
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final setMarket = ref.read(setTripMarketProvider);
  final previousName = ref.read(activeTripMarketNameProvider);
  try {
    var move = false;
    final recorded = trip.marketId == null ? 0 : await setMarket.recordedPrices(trip.id);
    if (recorded > 0 && previousName != null) {
      if (!context.mounted) return;
      final answer = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.tripMovePricesTitle(recorded, market.name)),
          content: Text(l10n.tripMovePricesBody(previousName)),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.tripMovePricesKeep)),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l10n.tripMovePricesMove)),
          ],
        ),
      );
      if (answer == null) return;
      move = answer;
    }
    await setMarket(trip.id, market.id, movePrices: move);
  } on Exception {
    messenger.showSnackBar(SnackBar(content: Text(l10n.tripMarketFailed)));
  }
}
