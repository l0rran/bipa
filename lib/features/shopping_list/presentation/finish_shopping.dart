import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/features/shopping_list/presentation/shopping_list_providers.dart';
import 'package:bipa/features/shopping_list/presentation/trip_review_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// "Terminei": mostra a folha "Fim da compra" e, confirmado, o comprado vai
/// para o estoque e sai da lista, com Desfazer. Usado na Lista, no modo
/// carrinho e na notificação, onde a folha também evita que um toque no
/// bolso encerre a compra.
Future<void> finishShopping(BuildContext context, WidgetRef ref, String tripId) async {
  // Lidos antes do await: a tela pode fechar quando a compra terminar.
  final review = ref.read(reviewShoppingTripProvider);
  final finish = ref.read(finishShoppingTripProvider);
  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppLocalizations.of(context);
  try {
    final summary = await review(tripId);
    if (summary == null || !context.mounted) return;
    if (!await showTripReview(context, summary)) return;
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
