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

enum LocationFailure {
  serviceDisabled('A localização do aparelho está desligada.'),
  permissionDenied('Permissão de localização negada.'),
  permissionDeniedForever(
    'Permissão de localização bloqueada. Libere nas configurações do aparelho.',
  ),
  timeout('Não foi possível obter a localização a tempo.'),
  unknown('Não foi possível obter a localização.');

  const LocationFailure(this.message);

  final String message;
}

/// Obtém a posição atual do aparelho. O GPS funciona sem internet.
abstract interface class LocationService {
  Future<LocationResult> currentLocation();
}
