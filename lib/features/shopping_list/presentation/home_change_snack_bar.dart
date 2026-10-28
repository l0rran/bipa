import 'dart:async';

import 'package:bipa/core/formatting/formatters.dart';
import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/shopping_list/domain/record_at_home.dart';
import 'package:flutter/material.dart';

/// O aviso de um bipe ou gesto em casa ([RecordAtHome]): diz o que mudou na
/// lista, ou no estoque quando a lista ficou como estava, com o "Desfazer"
/// que volta os dois. Devolve o controle do aviso, para quem precisa saber
/// quando ele sai da tela.
ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showHomeChangeSnackBar(
  ScaffoldMessengerState messenger, {
  required AppLocalizations l10n,
  required RecordAtHome record,
  required Product product,
  required HomeChange change,
}) {
  final applied = change.stock.applied;
  final message = switch (change.list) {
    RemovedFromList() => l10n.cameraOffList(product.name),
    ListQuantityLowered(:final before) => l10n.cameraStillMissing(before - 1, product.name),
    AddedToList() => l10n.cameraToList(product.name),
    ListUnchanged() => switch (applied) {
      > 0.0 => l10n.stockBoughtOneDone(product.name),
      -1.0 => l10n.stockUsedOneDone(product.name),
      // Com menos de uma embalagem em casa, a baixa tira só o que havia.
      _ => l10n.cameraUsedPart(Formatters.quantity(applied.abs()), product.name),
    },
  };

  Future<void> undo() async {
    try {
      await record.undo(change);
    } on Exception {
      messenger.showSnackBar(SnackBar(content: Text(l10n.cameraAdjustFailed)));
    }
  }

  messenger.hideCurrentSnackBar();
  return messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 4),
      action: SnackBarAction(label: l10n.undo, onPressed: () => unawaited(undo())),
    ),
  );
}
