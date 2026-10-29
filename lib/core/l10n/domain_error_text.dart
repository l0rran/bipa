import 'package:bipa/core/errors/domain_exception.dart';
import 'package:bipa/core/l10n/app_localizations.dart';

/// O texto do ARB para um erro de regra de negócio.
String domainErrorText(AppLocalizations l10n, DomainException error) => switch (error.code) {
  DomainErrorCode.invalidPrice => l10n.priceNotPositive,
  DomainErrorCode.missingProductName => l10n.productNameMissing,
  DomainErrorCode.productNotFound => l10n.productNotFound,
  DomainErrorCode.missingPackageProduct => l10n.packageProductMissing,
  DomainErrorCode.invalidPackageSize => l10n.packageSizeNotPositive,
  DomainErrorCode.scaleBarcode => l10n.barcodeScale,
  DomainErrorCode.packageNotFound => l10n.packageNotFound,
  DomainErrorCode.packageInOpenTrip => l10n.packageInOpenTrip,
  DomainErrorCode.duplicateBarcode => l10n.packageDuplicate(error.args[0], error.args[1]),
};
