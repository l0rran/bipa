import 'package:bipa/core/design_system/components/bipa_toast.dart';
import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/core/widgets/confirm_destructive.dart';
import 'package:bipa/features/shopping_list/presentation/shopping_list_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// "Cancelar compra": confirma e desiste. O carrinho é descartado, nada vai
/// para o estoque, e o marcado na compra volta a faltar. Não tem Desfazer,
/// por isso a confirmação. Usado no menu da Lista e na folha "Fim da
/// compra", que o "Terminei" do carrinho também abre (CE7).
Future<void> cancelShopping(BuildContext context, WidgetRef ref, String tripId) async {
  // Lidos antes do await: a tela pode fechar quando a compra acabar.
  final l10n = AppLocalizations.of(context);
  final cancel = ref.read(cancelShoppingTripProvider);
  final messenger = ScaffoldMessenger.of(context);
  final confirmed = await confirmDestructive(
    context,
    title: l10n.tripCancelTitle,
    body: l10n.tripCancelBody,
    confirmLabel: l10n.tripCancel,
    cancelLabel: l10n.tripKeep,
  );
  if (!confirmed) return;
  try {
    await cancel(tripId);
  } on Exception {
    showBipaToast(messenger, l10n.tripCancelFailed);
  }
}
