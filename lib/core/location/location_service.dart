import 'package:bipa/core/location/geo_point.dart';
import 'package:bipa/core/permissions/permission_access.dart';

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
  /// Se o app já pode usar a localização, sem perguntar nada.
  Future<PermissionAccess> access();

  /// Mostra o pedido do sistema, se ele ainda pergunta. Chame depois de dizer
  /// à pessoa para que serve.
  Future<PermissionAccess> requestAccess();

  /// A posição atual. Com [request] falso, não mostra o pedido de permissão:
  /// sem ela, devolve [LocationFailure.permissionDenied].
  Future<LocationResult> currentLocation({bool request = true});
}
