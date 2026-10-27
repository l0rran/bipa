import 'dart:async';

import 'package:bipa/core/location/geo_point.dart';
import 'package:bipa/core/location/location_service.dart';
import 'package:geolocator/geolocator.dart';

/// [LocationService] baseado no GPS do aparelho (não exige internet).
final class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService({this.timeLimit = const Duration(seconds: 10)});

  final Duration timeLimit;

  @override
  Future<LocationResult> currentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return const LocationUnavailable(LocationFailure.serviceDisabled);
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
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
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: timeLimit,
        ),
      );
      return LocationFound(_toPoint(position));
    } on TimeoutException {
      // Dentro de prédios o GPS pode demorar: a última posição conhecida
      // costuma bastar para identificar o mercado.
      final last = await Geolocator.getLastKnownPosition();
      return last == null
          ? const LocationUnavailable(LocationFailure.timeout)
          : LocationFound(_toPoint(last));
    } on Exception {
      return const LocationUnavailable(LocationFailure.unknown);
    }
  }

  static GeoPoint _toPoint(Position position) =>
      GeoPoint(latitude: position.latitude, longitude: position.longitude);
}
