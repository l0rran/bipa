import 'dart:math' as math;

import 'package:meta/meta.dart';

/// Coordenada geográfica (WGS 84).
@immutable
final class GeoPoint {
  const GeoPoint({required this.latitude, required this.longitude})
    : assert(latitude >= -90 && latitude <= 90, 'latitude fora do intervalo'),
      assert(longitude >= -180 && longitude <= 180, 'longitude fora do intervalo');

  final double latitude;
  final double longitude;

  static const _earthRadiusMeters = 6371008.8;

  /// Distância em metros até [other], pela fórmula de haversine.
  ///
  /// Calculada localmente, sem depender de serviços online.
  double distanceTo(GeoPoint other) {
    final lat1 = _toRadians(latitude);
    final lat2 = _toRadians(other.latitude);
    final deltaLat = _toRadians(other.latitude - latitude);
    final deltaLng = _toRadians(other.longitude - longitude);

    final a =
        math.pow(math.sin(deltaLat / 2), 2) +
        math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(deltaLng / 2), 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return _earthRadiusMeters * c;
  }

  /// Onde este ponto fica em relação a [origin], em metros para o leste e
  /// para o norte. É uma aproximação plana, boa para distâncias de bairro:
  /// serve para desenhar os mercados em volta de quem está olhando.
  ({double east, double north}) offsetFrom(GeoPoint origin) {
    final metersPerDegree = _earthRadiusMeters * math.pi / 180;
    return (
      east: (longitude - origin.longitude) * metersPerDegree * math.cos(_toRadians(origin.latitude)),
      north: (latitude - origin.latitude) * metersPerDegree,
    );
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180;

  @override
  bool operator ==(Object other) =>
      other is GeoPoint && other.latitude == latitude && other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => 'GeoPoint($latitude, $longitude)';
}
