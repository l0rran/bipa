import 'package:bipa/core/location/geo_point.dart';

/// Resultado de uma tentativa de obter a localização do aparelho.
sealed class LocationResult {
  const LocationResult();
}

final class LocationFound extends LocationResult {
  const LocationFound(this.point);

  final GeoPoint point;
}

final class LocationUnavailable extends LocationResult {
  const LocationUnavailable(this.failure);

  final LocationFailure failure;
}

/// O texto de cada falha fica no ARB (`LocationFailureLabel`).
enum LocationFailure { serviceDisabled, permissionDenied, permissionDeniedForever, timeout, unknown }

/// Obtém a posição atual do aparelho. O GPS funciona sem internet.
abstract interface class LocationService {
  Future<LocationResult> currentLocation();
}
