import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/features/prices/domain/price_condition.dart';

extension PriceConditionLabel on PriceCondition {
  /// Texto curto da condição, ou `null` para o preço que vale para qualquer cliente.
  String? label(AppLocalizations l10n) => switch (this) {
    AnyCustomer() => null,
    LoyaltyMembers() => l10n.priceConditionLoyalty,
    Wholesale(:final minimumQuantity?) => l10n.priceConditionWholesale(minimumQuantity),
    Wholesale() => l10n.priceConditionWholesaleUnknown,
  };
}
