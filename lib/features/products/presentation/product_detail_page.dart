import 'package:bipa/core/formatting/formatters.dart';
import 'package:bipa/core/navigation/routes.dart';
import 'package:bipa/core/widgets/async_value_view.dart';
import 'package:bipa/core/widgets/empty_state.dart';
import 'package:bipa/core/widgets/messages.dart';
import 'package:bipa/features/prices/domain/price_comparison.dart';
import 'package:bipa/features/prices/domain/price_observation.dart';
import 'package:bipa/features/prices/presentation/prices_providers.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/products/domain/unit_price.dart';
import 'package:bipa/features/products/presentation/products_providers.dart';
import 'package:bipa/features/stock/domain/stock_movement_reason.dart';
import 'package:bipa/features/stock/presentation/stock_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Detalhes do produto e comparação de preços entre mercados.
class ProductDetailPage extends ConsumerWidget {
  const ProductDetailPage({required this.productId, super.key});

  final String productId;

  Future<void> _addToStock(BuildContext context, WidgetRef ref, Product product) async {
    await ref
        .read(stockRepositoryProvider)
        .adjust(productId: product.id, delta: 1, reason: StockMovementReason.purchase);
    if (context.mounted) context.showMessage('${product.name} adicionado ao estoque.');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = ref.watch(productProvider(productId));

    // Material garante tema e tipografia durante o carregamento, antes do Scaffold.
    return Material(
      child: AsyncValueView(
        value: product,
        data: (product) => product == null
            ? Scaffold(
                appBar: AppBar(),
                body: const EmptyState(icon: Icons.search_off, message: 'Produto não encontrado.'),
              )
            : _buildDetail(context, ref, product),
      ),
    );
  }

  Widget _buildDetail(BuildContext context, WidgetRef ref, Product product) {
    return Scaffold(
      appBar: AppBar(
        title: Text(product.name),
        actions: [
          IconButton(
            tooltip: 'Editar',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push(Routes.editProduct(product.id)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ProductInfo(product: product),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => context.push(Routes.capturePriceFor(product.id)),
                  icon: const Icon(Icons.sell_outlined),
                  label: const Text('Registrar preço'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _addToStock(context, ref, product),
                  icon: const Icon(Icons.add_home_outlined),
                  label: const Text('Tenho em casa'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _PriceSection(product: product),
        ],
      ),
    );
  }
}

class _ProductInfo extends StatelessWidget {
  const _ProductInfo({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final details = [
      if (product.brand case final brand?) ('Marca', brand),
      if (product.packageLabel case final package?) ('Embalagem', package),
      if (product.barcode case final barcode?) ('Código de barras', barcode),
    ];
    if (details.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (label, value) in details)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
                    Text(value, style: theme.textTheme.bodyLarge),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PriceSection extends ConsumerWidget {
  const _PriceSection({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(priceHistoryProvider(product.id));
    final theme = Theme.of(context);

    return AsyncValueView(
      value: history,
      data: (entries) {
        if (entries.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(top: 32),
            child: EmptyState(
              icon: Icons.sell_outlined,
              message: 'Nenhum preço registrado ainda.\nFotografe a etiqueta no mercado.',
            ),
          );
        }

        final latest = latestPricePerMarket(entries);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Último preço em cada mercado', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final (index, entry) in latest.indexed)
              _PriceTile(product: product, entry: entry, isCheapest: index == 0 && latest.length > 1),
            const SizedBox(height: 24),
            Text('Histórico', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final entry in entries) _PriceTile(product: product, entry: entry, dense: true),
          ],
        );
      },
    );
  }
}

class _PriceTile extends StatelessWidget {
  const _PriceTile({
    required this.product,
    required this.entry,
    this.isCheapest = false,
    this.dense = false,
  });

  final Product product;
  final PriceHistoryEntry entry;
  final bool isCheapest;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final observation = entry.observation;
    final unitPrice = UnitPrice.of(
      price: observation.price,
      packageSize: product.packageSize,
      unit: product.unit,
    );
    final colors = Theme.of(context).colorScheme;
    final subtitle = [
      Formatters.date(observation.observedAt),
      observation.source.label,
      ?unitPrice?.format(),
    ].join(' · ');

    return ListTile(
      dense: dense,
      contentPadding: EdgeInsets.zero,
      title: Text(entry.marketName),
      subtitle: Text(subtitle),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            observation.price.format(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isCheapest ? colors.primary : null,
            ),
          ),
          if (observation.regularPrice case final regular? when observation.isPromotion)
            Text(
              regular.format(),
              style: const TextStyle(decoration: TextDecoration.lineThrough, fontSize: 12),
            )
          else if (isCheapest)
            Text('Menor preço', style: TextStyle(color: colors.primary, fontSize: 12)),
        ],
      ),
    );
  }
}
