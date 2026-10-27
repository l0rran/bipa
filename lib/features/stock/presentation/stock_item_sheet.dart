import 'package:bipa/core/formatting/formatters.dart';
import 'package:bipa/core/navigation/routes.dart';
import 'package:bipa/features/stock/domain/stock_item.dart';
import 'package:bipa/features/stock/domain/stock_location.dart';
import 'package:bipa/features/stock/presentation/stock_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Configurações de um item do estoque: local e quanto ter sempre.
Future<void> showStockItemSheet(BuildContext context, StockEntry entry) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => StockItemSheet(entry: entry),
  );
}

class StockItemSheet extends ConsumerStatefulWidget {
  const StockItemSheet({required this.entry, super.key});

  final StockEntry entry;

  @override
  ConsumerState<StockItemSheet> createState() => _StockItemSheetState();
}

class _StockItemSheetState extends ConsumerState<StockItemSheet> {
  late final _target = TextEditingController(
    text: switch (widget.entry.item.targetQuantity) {
      final target? => Formatters.quantity(target),
      null => '',
    },
  );
  late var _location = widget.entry.item.location;

  @override
  void dispose() {
    _target.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final repository = ref.read(stockRepositoryProvider);
    final productId = widget.entry.product.id;
    final text = _target.text.trim().replaceAll(',', '.');

    await repository.setTargetQuantity(productId, text.isEmpty ? null : double.tryParse(text));
    await repository.setLocation(productId, _location);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.entry.product;
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(product.name, style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          Text('Onde fica guardado', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final location in StockLocation.values)
                ChoiceChip(
                  label: Text(location.label),
                  selected: _location == location,
                  onSelected: (_) => setState(() => _location = location),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _target,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Ter sempre',
              helperText: 'Abaixo disso, o item aparece em "Acabando"',
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              TextButton(
                onPressed: () {
                  final router = GoRouter.of(context);
                  Navigator.of(context).pop();
                  router.push(Routes.productDetail(product.id));
                },
                child: const Text('Ver produto e preços'),
              ),
              const Spacer(),
              FilledButton(onPressed: _save, child: const Text('Salvar')),
            ],
          ),
        ],
      ),
    );
  }
}
