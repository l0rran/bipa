import 'package:bipa/core/navigation/routes.dart';
import 'package:bipa/core/widgets/async_value_view.dart';
import 'package:bipa/features/markets/domain/market.dart';
import 'package:bipa/features/markets/presentation/markets_page.dart';
import 'package:bipa/features/markets/presentation/markets_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Abre a seleção de mercado e devolve o escolhido (ou `null`).
Future<Market?> pickMarket(BuildContext context, {String? selectedId}) {
  return showModalBottomSheet<Market>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => MarketPickerSheet(selectedId: selectedId),
  );
}

class MarketPickerSheet extends ConsumerWidget {
  const MarketPickerSheet({this.selectedId, super.key});

  final String? selectedId;

  Future<void> _createMarket(BuildContext context) async {
    final created = await context.push<Market>(Routes.newMarket);
    if (created != null && context.mounted) Navigator.of(context).pop(created);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final markets = ref.watch(rankedMarketsProvider);

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
      child: AsyncValueView(
        value: markets,
        data: (ranked) => ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text('Em qual mercado você está?', style: Theme.of(context).textTheme.titleMedium),
            ),
            for (final item in ranked)
              MarketTile(
                ranked: item,
                selected: item.market.id == selectedId,
                onTap: () => Navigator.of(context).pop(item.market),
              ),
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.add)),
              title: const Text('Cadastrar novo mercado'),
              onTap: () => _createMarket(context),
            ),
          ],
        ),
      ),
    );
  }
}
