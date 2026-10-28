import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/features/markets/domain/market.dart';
import 'package:bipa/features/markets/domain/nearest_market_finder.dart';
import 'package:bipa/features/markets/presentation/market_meta.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('pt'));
  final created = DateTime(2026);
  final now = DateTime(2026, 10, 28, 8);
  RankedMarket item({double? distance, String? address}) => RankedMarket(
    Market(id: 'm', name: 'Atacarejo', address: address, createdAt: created, updatedAt: created),
    distance,
  );

  test('junta a distância e a idade dos preços', () {
    expect(
      marketMeta(l10n, item(distance: 850), isHere: false, latestPrice: DateTime(2026, 10, 23, 20), now: now),
      '850 m · preços de 5 dias',
    );
  });

  test('conta a idade em dias do calendário', () {
    expect(
      marketMeta(l10n, item(), isHere: false, latestPrice: DateTime(2026, 10, 27, 22), now: now),
      'preços de ontem',
    );
  });

  test('sem distância nem preço, mostra o endereço ou a falta de ponto', () {
    expect(marketMeta(l10n, item(address: 'Rua A'), isHere: false, latestPrice: null, now: now), 'Rua A');
    expect(marketMeta(l10n, item(), isHere: false, latestPrice: null, now: now), l10n.marketsNoPoint);
  });

  test('dentro do mercado, só diz que você está nele', () {
    expect(marketMeta(l10n, item(distance: 20), isHere: true, latestPrice: now, now: now), l10n.marketsHere);
    expect(marketMetaIcon(item(), isHere: true), isNotNull);
    expect(marketMetaIcon(item(), isHere: false), isNull);
  });
}
