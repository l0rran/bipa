import 'package:bipa/core/formatting/formatters.dart';
import 'package:bipa/core/location/location_service.dart';
import 'package:bipa/core/navigation/routes.dart';
import 'package:bipa/core/widgets/async_value_view.dart';
import 'package:bipa/core/widgets/empty_state.dart';
import 'package:bipa/features/markets/domain/nearest_market_finder.dart';
import 'package:bipa/features/markets/presentation/markets_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Mercados cadastrados, do mais próximo ao mais distante.
class MarketsPage extends ConsumerWidget {
  const MarketsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final markets = ref.watch(rankedMarketsProvider);
    final location = ref.watch(currentLocationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mercados'),
        actions: [
          IconButton(
            tooltip: 'Atualizar localização',
            icon: const Icon(Icons.my_location),
            onPressed: () => ref.invalidate(currentLocationProvider),
          ),
          IconButton(
            tooltip: 'Novo mercado',
            icon: const Icon(Icons.add_business_outlined),
            onPressed: () => context.push(Routes.newMarket),
          ),
        ],
      ),
      body: Column(
        children: [
          if (location case AsyncData(value: LocationUnavailable(:final failure)))
            MaterialBanner(
              content: Text('${failure.message} Os mercados estão em ordem alfabética.'),
              leading: const Icon(Icons.location_off_outlined),
              actions: [
                TextButton(
                  onPressed: () => ref.invalidate(currentLocationProvider),
                  child: const Text('Tentar de novo'),
                ),
              ],
            ),
          Expanded(
            child: AsyncValueView(
              value: markets,
              data: (ranked) => ranked.isEmpty
                  ? EmptyState(
                      icon: Icons.storefront_outlined,
                      message:
                          'Nenhum mercado cadastrado.\nCadastre os mercados onde você costuma comprar.',
                      actionLabel: 'Cadastrar mercado',
                      onAction: () => context.push(Routes.newMarket),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: 96),
                      itemCount: ranked.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) => MarketTile(
                        ranked: ranked[index],
                        onTap: () => context.push(Routes.editMarket(ranked[index].market.id)),
                      ),
                    ),
            ),
          ),
        ],
      ),
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
    final colors = Theme.of(context).colorScheme;

    return ListTile(
      selected: selected,
      leading: CircleAvatar(
        backgroundColor: isHere ? colors.primaryContainer : null,
        child: Icon(isHere ? Icons.where_to_vote : Icons.storefront_outlined),
      ),
      title: Text(market.name),
      subtitle: Text(
        [
          if (isHere) 'Você está aqui',
          ?market.address,
          if (market.location == null) 'Sem localização',
        ].join(' · '),
      ),
      trailing: distance == null ? null : Text(Formatters.distance(distance)),
      onTap: onTap,
    );
  }
}
