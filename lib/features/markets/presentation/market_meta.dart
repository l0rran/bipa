import 'package:bipa/core/formatting/formatters.dart';
import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/core/l10n/meta_join.dart';
import 'package:bipa/features/markets/domain/nearest_market_finder.dart';
import 'package:flutter/material.dart';

/// A linha de apoio de um mercado: "você está aqui", ou "850 m · preços de
/// 5 dias". Sem distância nem preço, o endereço (ou que não tem ponto no
/// mapa). Usada na lista de Mercados e na tela do mercado.
String marketMeta(
  AppLocalizations l10n,
  RankedMarket item, {
  required bool isHere,
  required DateTime? latestPrice,
  required DateTime now,
}) {
  if (isHere) return l10n.marketsHere;
  final distance = item.distanceMeters;
  // Em dias do calendário, como a idade do preço na tela do produto.
  final days = latestPrice == null ? null : DateUtils.dateOnly(now).difference(DateUtils.dateOnly(latestPrice)).inDays;
  return l10n.joinMeta([
    if (distance != null) Formatters.distance(distance),
    if (days != null) l10n.marketsPriceAge(days),
    if (distance == null && days == null) item.market.address ?? l10n.marketsNoPoint,
  ]);
}

/// O alfinete acompanha a linha quando ela fala de lugar.
IconData? marketMetaIcon(RankedMarket item, {required bool isHere}) =>
    isHere || item.distanceMeters != null ? Icons.place_outlined : null;
