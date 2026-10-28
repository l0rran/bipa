import 'package:bipa/core/catalog/product_kind.dart';
import 'package:bipa/core/l10n/app_localizations.dart';

/// O nome da seção do mercado, como a lista e a notificação da compra mostram.
extension AisleLabel on Aisle {
  String localizedLabel(AppLocalizations l10n) => switch (this) {
    Aisle.produce => l10n.aisleProduce,
    Aisle.bakery => l10n.aisleBakery,
    Aisle.meat => l10n.aisleMeat,
    Aisle.dairy => l10n.aisleDairy,
    Aisle.grocery => l10n.aisleGrocery,
    Aisle.sweets => l10n.aisleSweets,
    Aisle.frozen => l10n.aisleFrozen,
    Aisle.drinks => l10n.aisleDrinks,
    Aisle.cleaning => l10n.aisleCleaning,
    Aisle.hygiene => l10n.aisleHygiene,
    Aisle.pet => l10n.aislePet,
    Aisle.other => l10n.aisleOther,
  };
}
