import 'package:bipa/core/location/geo_point.dart';
import 'package:bipa/features/markets/domain/market.dart';
import 'package:bipa/features/markets/domain/nearest_market_finder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026);
  const user = GeoPoint(latitude: -23.5500, longitude: -46.6300);

  Market market(String name, {GeoPoint? location}) => Market(
    id: name,
    name: name,
    location: location,
    createdAt: now,
    updatedAt: now,
  );

  // ~111 m ao norte do usuário.
  final pertinho = market(
    'Pertinho',
    location: const GeoPoint(latitude: -23.5490, longitude: -46.6300),
  );
  // ~1,1 km ao norte do usuário.
  final longe = market(
    'Longe',
    location: const GeoPoint(latitude: -23.5400, longitude: -46.6300),
  );
  final semLocalizacao = market('Atacadão');

  const finder = NearestMarketFinder();

  test('rank ordena por distância e deixa os sem localização no fim', () {
    final ranked = finder.rank(user, [semLocalizacao, longe, pertinho]);

    expect(ranked.map((r) => r.market.name), ['Pertinho', 'Longe', 'Atacadão']);
    expect(ranked.first.distanceMeters, closeTo(111, 2));
    expect(ranked.last.distanceMeters, isNull);
  });

  test('rank sem posição do usuário ordena por nome', () {
    final ranked = finder.rank(null, [pertinho, longe, semLocalizacao]);
    expect(ranked.map((r) => r.market.name), ['Atacadão', 'Longe', 'Pertinho']);
  });

  test('marketAt encontra o mercado dentro do raio', () {
    expect(finder.marketAt(user, [longe, pertinho]), pertinho);
  });

  test('marketAt retorna null quando nenhum mercado está perto', () {
    expect(finder.marketAt(user, [longe, semLocalizacao]), isNull);
    expect(finder.marketAt(user, const []), isNull);
  });

  test('raio de presença é configurável', () {
    const generoso = NearestMarketFinder(presenceRadiusMeters: 2000);
    expect(generoso.marketAt(user, [longe]), longe);
  });
}
