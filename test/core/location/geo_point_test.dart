import 'package:bipa/core/location/geo_point.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('distância até o mesmo ponto é zero', () {
    const point = GeoPoint(latitude: -23.5503, longitude: -46.6339);
    expect(point.distanceTo(point), 0);
  });

  test('um milésimo de grau de latitude equivale a ~111 m', () {
    const a = GeoPoint(latitude: 0, longitude: 0);
    const b = GeoPoint(latitude: 0.001, longitude: 0);
    expect(a.distanceTo(b), closeTo(111.2, 0.5));
  });

  test('distância é simétrica', () {
    const saoPaulo = GeoPoint(latitude: -23.5505, longitude: -46.6333);
    const rio = GeoPoint(latitude: -22.9068, longitude: -43.1729);

    expect(saoPaulo.distanceTo(rio), closeTo(rio.distanceTo(saoPaulo), 0.001));
    // Distância em linha reta entre as capitais: ~360 km.
    expect(saoPaulo.distanceTo(rio), closeTo(360000, 5000));
  });
}
