import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/features/shopping_list/domain/shopping_trip.dart';

/// O total da compra como as telas mostram: "≈ R$ 54,88" quando algum preço
/// ainda é o do histórico.
extension TripSummaryLabel on ShoppingTripSummary {
  String? spentLabel(AppLocalizations l10n) => switch (spent) {
    final spent? when estimated => l10n.priceEstimate(spent.format()),
    final spent? => spent.format(),
    null => null,
  };
}
