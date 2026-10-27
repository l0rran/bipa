import 'package:bipa/core/navigation/routes.dart';
import 'package:bipa/core/widgets/async_value_view.dart';
import 'package:bipa/core/widgets/empty_state.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/products/presentation/products_providers.dart';
import 'package:bipa/features/products/presentation/scan_product.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Lista de produtos cadastrados, com busca por nome, marca ou código.
class ProductsPage extends ConsumerWidget {
  const ProductsPage({super.key});

  Future<void> _scan(BuildContext context, WidgetRef ref) async {
    final product = await scanAndResolveProduct(context, ref);
    if (product != null && context.mounted) {
      await context.push(Routes.productDetail(product.id));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(productsProvider);
    final query = ref.watch(productSearchQueryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Produtos'),
        actions: [
          IconButton(
            tooltip: 'Buscar pelo código de barras',
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () => _scan(context, ref),
          ),
          IconButton(
            tooltip: 'Novo produto',
            icon: const Icon(Icons.add),
            onPressed: () => context.push(Routes.newProduct),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SearchBar(
              hintText: 'Buscar por nome, marca ou código',
              leading: const Icon(Icons.search),
              elevation: const WidgetStatePropertyAll(0),
              onChanged: ref.read(productSearchQueryProvider.notifier).change,
            ),
          ),
        ),
      ),
      body: AsyncValueView(
        value: products,
        data: (items) {
          if (items.isEmpty) {
            return query.isEmpty
                ? EmptyState(
                    icon: Icons.inventory_2_outlined,
                    message: 'Nenhum produto ainda.\nBipe um código de barras para começar.',
                    actionLabel: 'Ler código de barras',
                    onAction: () => _scan(context, ref),
                  )
                : const EmptyState(
                    icon: Icons.search_off,
                    message: 'Nenhum produto encontrado.',
                  );
          }
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) => _ProductTile(product: items[index]),
          );
        },
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final subtitle = product.subtitle;
    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.shopping_basket_outlined)),
      title: Text(product.name),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(Routes.productDetail(product.id)),
    );
  }
}
