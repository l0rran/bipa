import 'package:bipa/core/formatting/formatters.dart';
import 'package:bipa/core/widgets/async_value_view.dart';
import 'package:bipa/core/widgets/empty_state.dart';
import 'package:bipa/core/widgets/messages.dart';
import 'package:bipa/features/products/presentation/scan_product.dart';
import 'package:bipa/features/stock/domain/stock_item.dart';
import 'package:bipa/features/stock/domain/stock_movement_reason.dart';
import 'package:bipa/features/stock/presentation/stock_item_sheet.dart';
import 'package:bipa/features/stock/presentation/stock_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// O que há em casa, com destaque para o que está acabando.
class StockPage extends ConsumerWidget {
  const StockPage({super.key});

  Future<void> _addByBarcode(BuildContext context, WidgetRef ref) async {
    final product = await scanAndResolveProduct(context, ref);
    if (product == null) return;

    await ref
        .read(stockRepositoryProvider)
        .adjust(productId: product.id, delta: 1, reason: StockMovementReason.purchase);
    if (context.mounted) context.showMessage('+1 ${product.name}');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stock = ref.watch(stockProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Estoque'),
        actions: [
          IconButton(
            tooltip: 'Adicionar pelo código de barras',
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () => _addByBarcode(context, ref),
          ),
        ],
      ),
      body: AsyncValueView(
        value: stock,
        data: (entries) {
          if (entries.isEmpty) {
            return EmptyState(
              icon: Icons.kitchen_outlined,
              message: 'Seu estoque está vazio.\nBipe os produtos que você tem em casa.',
              actionLabel: 'Ler código de barras',
              onAction: () => _addByBarcode(context, ref),
            );
          }

          final low = entries.where((e) => e.item.isLow).toList();
          final ok = entries.where((e) => !e.item.isLow).toList();
          return ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              if (low.isNotEmpty) ...[
                const _SectionHeader('Acabando'),
                for (final entry in low) _StockTile(entry: entry),
              ],
              if (ok.isNotEmpty) ...[
                const _SectionHeader('Em casa'),
                for (final entry in ok) _StockTile(entry: entry),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary),
      ),
    );
  }
}

class _StockTile extends ConsumerWidget {
  const _StockTile({required this.entry});

  final StockEntry entry;

  Future<void> _adjust(WidgetRef ref, double delta) {
    return ref.read(stockRepositoryProvider).adjust(
      productId: entry.product.id,
      delta: delta,
      reason: delta > 0 ? StockMovementReason.purchase : StockMovementReason.consumption,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = entry.item;
    final colors = Theme.of(context).colorScheme;
    final minimum = item.minimumQuantity;

    return ListTile(
      title: Text(entry.product.name),
      subtitle: Text(
        [
          item.location.label,
          if (minimum != null) 'mínimo ${Formatters.quantity(minimum)}',
        ].join(' · '),
      ),
      onTap: () => showStockItemSheet(context, entry),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Usei um',
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: item.isOut ? null : () => _adjust(ref, -1),
          ),
          SizedBox(
            width: 40,
            child: Text(
              Formatters.quantity(item.quantity),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: item.isLow ? colors.error : null,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Comprei um',
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => _adjust(ref, 1),
          ),
        ],
      ),
    );
  }
}
