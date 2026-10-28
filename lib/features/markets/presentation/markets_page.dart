import 'package:bipa/core/catalog/text_fold.dart';
import 'package:bipa/core/design_system/bipa_metrics.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/design_system/bipa_typography.dart';
import 'package:bipa/core/design_system/components/bipa_search_bar.dart';
import 'package:bipa/core/design_system/components/list_cost_compare.dart';
import 'package:bipa/core/design_system/components/market_map.dart';
import 'package:bipa/core/design_system/components/price_rows.dart';
import 'package:bipa/core/design_system/components/section_header.dart';
import 'package:bipa/core/di/core_providers.dart';
import 'package:bipa/core/formatting/formatters.dart';
import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/core/location/location_failure_label.dart';
import 'package:bipa/core/location/location_service.dart';
import 'package:bipa/core/navigation/routes.dart';
import 'package:bipa/core/widgets/async_value_view.dart';
import 'package:bipa/core/widgets/empty_state.dart';
import 'package:bipa/features/markets/domain/nearest_market_finder.dart';
import 'package:bipa/features/markets/presentation/markets_providers.dart';
import 'package:bipa/features/prices/domain/list_cost.dart';
import 'package:bipa/features/prices/presentation/prices_providers.dart';
import 'package:bipa/features/shopping_list/presentation/shopping_list_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Mercados (protótipo "Mercados"): a busca, o mapa dos mercados em volta,
/// quanto a lista custa em cada um e os mercados do mais perto ao mais longe,
/// com a idade dos preços de cada um.
class MarketsPage extends ConsumerStatefulWidget {
  const MarketsPage({super.key});

  @override
  ConsumerState<MarketsPage> createState() => _MarketsPageState();
}

class _MarketsPageState extends ConsumerState<MarketsPage> {
  String _query = '';

  List<RankedMarket> _visible(List<RankedMarket> ranked) {
    final query = foldText(_query.trim());
    return [
      for (final item in ranked)
        if (query.isEmpty || foldText(item.market.name).contains(query)) item,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final markets = ref.watch(rankedMarketsProvider);
    final location = ref.watch(currentLocationProvider);
    final finder = ref.watch(nearestMarketFinderProvider);
    final costs = ref.watch(listCostPerMarketProvider);
    final latestPrices = ref.watch(latestPricePerMarketProvider).value ?? const <String, DateTime>{};
    final now = ref.watch(clockProvider)();
    final here = switch (location) {
      AsyncData(value: LocationFound(:final point)) => point,
      _ => null,
    };
    // A comparação só faz sentido com dois mercados ou mais.
    final compare = costs.length > 1 ? costs : const <MarketListCost>[];
    final cheapestId = compare.firstOrNull?.marketId;

    return Scaffold(
      body: AsyncValueView(
        value: markets,
        data: (ranked) {
          if (ranked.isEmpty) {
            return EmptyState(
              icon: Icons.storefront_outlined,
              message: l10n.marketsEmpty,
              actionLabel: l10n.marketsEmptyAction,
              onAction: () => context.push(Routes.newMarket),
            );
          }
          final visible = _visible(ranked);
          final onMap = [
            if (here != null)
              for (final item in visible)
                if (item.market.location case final point?) (item: item, point: point),
          ];
          return RefreshIndicator(
            // Puxar para baixo procura a localização de novo.
            onRefresh: () => ref.refresh(currentLocationProvider.future),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                BipaSpacing.s4,
                MediaQuery.paddingOf(context).top + BipaSpacing.s6,
                BipaSpacing.s4,
                // Espaço para as barras flutuantes (navegação e compra).
                MediaQuery.paddingOf(context).bottom + BipaSpacing.s8,
              ),
              children: [
                Semantics(
                  header: true,
                  child: Text(l10n.navMarkets, style: BipaText.headline.copyWith(color: colors.ink)),
                ),
                const SizedBox(height: BipaSpacing.s4),
                BipaSearchBar(
                  hint: l10n.marketsSearch,
                  onChanged: (value) => setState(() => _query = value),
                  onScan: () => context.push(Routes.capturePrice),
                  scanLabel: l10n.searchScan,
                ),
                if (location case AsyncData(value: LocationUnavailable(:final failure))) ...[
                  const SizedBox(height: BipaSpacing.s3),
                  _NoLocation(
                    message: l10n.marketsNoLocation(failure.localizedLabel(l10n)),
                    retryLabel: l10n.retry,
                    onRetry: () => ref.invalidate(currentLocationProvider),
                  ),
                ],
                if (here != null && onMap.isNotEmpty) ...[
                  const SizedBox(height: BipaSpacing.s6),
                  MarketMap(
                    semanticsLabel: l10n.marketsMapLabel(onMap.length),
                    pins: [
                      for (final (:item, :point) in onMap)
                        _pin(point.offsetFrom(here), here: finder.isInside(item), best: item.market.id == cheapestId),
                    ],
                  ),
                ],
                if (compare.isNotEmpty) ...[
                  const SizedBox(height: BipaSpacing.s6),
                  SectionHeader(title: l10n.marketsListCost),
                  const SizedBox(height: BipaSpacing.s2),
                  ListCostCompare(
                    bestLabel: l10n.marketsCheapest,
                    rows: [
                      for (final cost in compare)
                        ListCostRow(
                          name: cost.marketName,
                          value: cost.total.format(),
                          fraction: cost.total.cents / _highest(compare),
                          note: cost.isPartial ? l10n.marketsMissingPrices(cost.items - cost.priced) : null,
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: BipaSpacing.s6),
                SectionHeader(
                  title: here == null ? l10n.marketsYours : l10n.marketsNearby,
                  count: visible.length,
                ),
                const SizedBox(height: BipaSpacing.s2),
                PriceRowList(
                  rows: [
                    for (final item in visible) _row(l10n, item, finder.isInside(item), latestPrices, now),
                    PriceRowData(
                      icon: Icons.add_rounded,
                      title: l10n.marketsEmptyAction,
                      onTap: () => context.push(Routes.newMarket),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static int _highest(List<MarketListCost> costs) =>
      costs.map((c) => c.total.cents).fold(1, (max, cents) => cents > max ? cents : max);

  static MarketMapPin _pin(({double east, double north}) offset, {required bool here, required bool best}) =>
      MarketMapPin(east: offset.east, north: offset.north, here: here, best: best);

  /// "você está aqui", ou "850 m · preços de 5 dias".
  PriceRowData _row(
    AppLocalizations l10n,
    RankedMarket item,
    bool isHere,
    Map<String, DateTime> latestPrices,
    DateTime now,
  ) {
    final market = item.market;
    final distance = item.distanceMeters;
    final latest = latestPrices[market.id];
    final days = latest == null ? null : DateUtils.dateOnly(now).difference(DateUtils.dateOnly(latest)).inDays;
    final meta = isHere
        ? l10n.marketsHere
        : [
            if (distance != null) Formatters.distance(distance),
            if (days != null) l10n.marketsPriceAge(days),
            if (distance == null && days == null) market.address ?? l10n.marketsNoPoint,
          ].join(' · ');
    return PriceRowData(
      icon: Icons.storefront_outlined,
      place: true,
      title: market.name,
      meta: meta,
      metaIcon: isHere || distance != null ? Icons.place_outlined : null,
      onTap: () => context.push(Routes.editMarket(market.id)),
    );
  }
}

/// A localização não veio: os mercados ficam em ordem alfabética.
class _NoLocation extends StatelessWidget {
  const _NoLocation({required this.message, required this.retryLabel, required this.onRetry});

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        Icon(Icons.location_off_outlined, size: 18, color: colors.inkMuted),
        const SizedBox(width: BipaSpacing.s2),
        Expanded(child: Text(message, style: BipaText.body.copyWith(fontSize: 13, color: colors.inkMuted))),
        TextButton(onPressed: onRetry, child: Text(retryLabel)),
      ],
    );
  }
}

/// Linha de mercado com distância e indicação de "você está aqui".
class MarketTile extends ConsumerWidget {
  const MarketTile({required this.ranked, required this.onTap, this.selected = false, super.key});

  final RankedMarket ranked;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final market = ranked.market;
    final distance = ranked.distanceMeters;
    final isHere = ref.watch(nearestMarketFinderProvider).isInside(ranked);
    final l10n = AppLocalizations.of(context);

    return ListTile(
      selected: selected,
      leading: CircleAvatar(
        backgroundColor: isHere ? context.colors.placeSoft : null,
        child: Icon(isHere ? Icons.where_to_vote : Icons.storefront_outlined),
      ),
      title: Text(market.name),
      subtitle: Text(
        [
          if (isHere) l10n.marketsHere,
          ?market.address,
          if (market.location == null) l10n.marketsNoPoint,
        ].join(' · '),
      ),
      trailing: distance == null ? null : Text(Formatters.distance(distance)),
      onTap: onTap,
    );
  }
}
