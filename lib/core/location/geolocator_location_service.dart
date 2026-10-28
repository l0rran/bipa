import 'dart:async';

import 'package:bipa/core/location/geo_point.dart';
import 'package:bipa/core/location/location_service.dart';
import 'package:bipa/core/permissions/permission_access.dart';
import 'package:geolocator/geolocator.dart';

/// [LocationService] baseado no GPS do aparelho (não exige internet).
final class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService({this.timeLimit = const Duration(seconds: 10)});

  final Duration timeLimit;

  /// No Android, o `checkPermission` pode responder "negado" mesmo depois de
  /// uma negação de vez (o "de vez" só vem do pedido). Aí o app explica o
  /// motivo uma vez a mais e o `requestAccess` volta bloqueado, sem diálogo.
  @override
  Future<PermissionAccess> access() async => _toAccess(await Geolocator.checkPermission());

  @override
  Future<PermissionAccess> requestAccess() async {
    final permission = await Geolocator.checkPermission();
    // Só o "negado" ainda pergunta; os outros estados não mudam pelo pedido.
    return _toAccess(permission == LocationPermission.denied ? await Geolocator.requestPermission() : permission);
  }

  @override
  Future<LocationResult> currentLocation({bool request = true}) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return const LocationUnavailable(LocationFailure.serviceDisabled);
    }

    var permission = await Geolocator.checkPermission();
    if (request && permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      return const LocationUnavailable(LocationFailure.permissionDenied);
    }
    if (permission == LocationPermission.deniedForever) {
      return const LocationUnavailable(LocationFailure.permissionDeniedForever);
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(accuracy: LocationAccuracy.high, timeLimit: timeLimit),
      );
      return LocationFound(_toPoint(position));
    } on TimeoutException {
      // Dentro de prédios o GPS pode demorar: a última posição conhecida
      // costuma bastar para identificar o mercado.
      final last = await Geolocator.getLastKnownPosition();
      return last == null ? const LocationUnavailable(LocationFailure.timeout) : LocationFound(_toPoint(last));
    } on Exception {
      return const LocationUnavailable(LocationFailure.unknown);
    }
  }

  static PermissionAccess _toAccess(LocationPermission permission) => switch (permission) {
    LocationPermission.always || LocationPermission.whileInUse => PermissionAccess.granted,
    LocationPermission.deniedForever => PermissionAccess.blocked,
    LocationPermission.denied || LocationPermission.unableToDetermine => PermissionAccess.askable,
  };

  static GeoPoint _toPoint(Position position) => GeoPoint(latitude: position.latitude, longitude: position.longitude);
}
