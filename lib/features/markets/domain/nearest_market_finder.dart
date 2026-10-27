import 'package:bipa/core/location/geo_point.dart';
import 'package:bipa/features/markets/domain/market.dart';
import 'package:meta/meta.dart';

/// Mercado acompanhado da distância até o usuário, quando conhecida.
@immutable
final class RankedMarket {
  const RankedMarket(this.market, this.distanceMeters);

  final Market market;
  final double? distanceMeters;
}

/// Ordena mercados por proximidade e identifica em qual o usuário está.
final class NearestMarketFinder {
  const NearestMarketFinder({this.presenceRadiusMeters = 150});

  /// Distância máxima para considerar que o usuário está dentro do mercado.
  final double presenceRadiusMeters;

  /// Mercados com localização vêm primeiro, do mais próximo ao mais distante;
  /// os demais vêm em seguida, por ordem alfabética.
  ///
  /// Sem a posição do usuário ([from] nulo), ordena apenas por nome.
  List<RankedMarket> rank(GeoPoint? from, Iterable<Market> markets) {
    final located = <RankedMarket>[];
    final others = <RankedMarket>[];

    for (final market in markets) {
      final location = market.location;
      if (from != null && location != null) {
        located.add(RankedMarket(market, from.distanceTo(location)));
      } else {
        others.add(RankedMarket(market, null));
      }
    }

    located.sort((a, b) => a.distanceMeters!.compareTo(b.distanceMeters!));
    others.sort((a, b) => a.market.name.toLowerCase().compareTo(b.market.name.toLowerCase()));
    return [...located, ...others];
  }

  /// Mercado em que o usuário provavelmente está, ou `null` se nenhum estiver
  /// dentro de [presenceRadiusMeters].
  Market? marketAt(GeoPoint position, Iterable<Market> markets) {
    final nearest = rank(position, markets).firstOrNull;
    final distance = nearest?.distanceMeters;
    if (nearest == null || distance == null) return null;
    return distance <= presenceRadiusMeters ? nearest.market : null;
  }

  bool isInside(RankedMarket ranked) {
    final distance = ranked.distanceMeters;
    return distance != null && distance <= presenceRadiusMeters;
  }
}
