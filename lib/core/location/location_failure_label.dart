import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/core/location/location_service.dart';

/// O que dizer quando a localização não vem.
extension LocationFailureLabel on LocationFailure {
  String localizedLabel(AppLocalizations l10n) => switch (this) {
    LocationFailure.serviceDisabled => l10n.locationServiceDisabled,
    LocationFailure.permissionDenied => l10n.locationPermissionDenied,
    LocationFailure.permissionDeniedForever => l10n.locationPermissionBlocked,
    LocationFailure.timeout => l10n.locationTimeout,
    LocationFailure.unknown => l10n.locationUnknown,
  };
}
