import 'package:bipa/core/design_system/bipa_metrics.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/design_system/bipa_typography.dart';
import 'package:bipa/core/design_system/components/bipa_toast.dart';
import 'package:bipa/core/design_system/components/quantity_stepper.dart';
import 'package:bipa/core/di/core_providers.dart';
import 'package:bipa/core/formatting/formatters.dart';
import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/core/navigation/routes.dart';
import 'package:bipa/core/widgets/confirm_destructive.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/shopping_list/presentation/shopping_list_providers.dart';
import 'package:bipa/features/stock/domain/stock_item.dart';
import 'package:bipa/features/stock/domain/stock_location.dart';
import 'package:bipa/features/stock/domain/stock_movement_reason.dart';
import 'package:bipa/features/stock/domain/suggested_location.dart';
import 'package:bipa/features/stock/presentation/stock_display.dart';
import 'package:bipa/features/stock/presentation/stock_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Abre o editor de um item de casa: quanto há, a lista, o "ter sempre" e
/// onde fica. Serve também para um produto que ainda não está em casa.
/// Aberto da tela do produto ([fromProduct]), não mostra "Ver produto".
Future<void> showStockItemSheet(BuildContext context, Product product, {bool fromProduct = false}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => BipaSheetToasts(
      child: StockItemSheet(product: product, fromProduct: fromProduct),
    ),
  );
}

/// O editor do item de casa. Tudo vale na hora, sem "Salvar": é o mesmo que
/// abre no "Acabando", no ajuste da linha e no cartão "Em casa" do produto.
class StockItemSheet extends ConsumerWidget {
  const StockItemSheet({required this.product, this.fromProduct = false, super.key});

  final Product product;
  final bool fromProduct;

  /// Executa uma mudança no estoque e, se o banco falhar, avisa como a tela
  /// do produto (H11): sem isso o número não muda e nada diz por quê.
  Future<void> _guard(BuildContext context, Future<void> Function() change) async {
    final messenger = ScaffoldMessenger.of(context);
    final message = AppLocalizations.of(context).stockAdjustFailed;
    try {
      await change();
    } on Exception {
      showBipaToast(messenger, message);
    }
  }

  Future<void> _adjust(BuildContext context, WidgetRef ref, double delta) => _guard(
    context,
    () => ref
        .read(stockRepositoryProvider)
        .adjust(
          productId: product.id,
          delta: delta,
          reason: delta > 0 ? StockMovementReason.purchase : StockMovementReason.consumption,
        ),
  );

  /// "Ter sempre": − até 1 e depois some (sem alerta); + a partir do nada
  /// começa em 1.
  Future<void> _setTarget(BuildContext context, WidgetRef ref, double? target) =>
      _guard(context, () => ref.read(stockRepositoryProvider).setTargetQuantity(product.id, target));

  Future<void> _setLocation(BuildContext context, WidgetRef ref, StockLocation location) =>
      _guard(context, () => ref.read(stockRepositoryProvider).setLocation(product.id, location));

  Future<void> _toggleList(WidgetRef ref, {required bool onList}) => onList
      ? ref.read(shoppingListRepositoryProvider).removeProduct(product.id)
      : ref.read(putProductOnListProvider)(product);

  /// "Tirar de casa": o produto sai do Início (e do "Acabando"); ele e os
  /// preços continuam.
  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final repository = ref.read(stockRepositoryProvider);
    final confirmed = await confirmDestructive(
      context,
      title: l10n.stockRemoveTitle(product.name),
      body: l10n.stockRemoveBody,
      confirmLabel: l10n.stockRemove,
    );
    if (!confirmed) return;
    await repository.remove(product.id);
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final entry = (ref.watch(stockProvider).value ?? const <StockEntry>[])
        .where((e) => e.product.id == product.id)
        .firstOrNull;
    // Sem item em casa, o local marcado é o que o item terá quando nascer
    // (o lembrado de quando saiu ou o sugerido, ADR 0021), e não um que
    // mudaria sozinho no primeiro "+". Enquanto o banco responde, o sugerido.
    final item =
        entry?.item ??
        StockItem(
          productId: product.id,
          quantity: 0,
          location: ref.watch(newItemLocationProvider(product.id)).value ?? suggestedLocation(product.name),
          updatedAt: ref.watch(clockProvider)(),
        );
    final target = item.targetQuantity;
    final onList = ref.watch(productsOnListProvider).contains(product.id);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        BipaSpacing.s4,
        0,
        BipaSpacing.s4,
        BipaSpacing.s4 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(product.name, style: BipaText.title.copyWith(color: colors.ink)),
            const SizedBox(height: BipaSpacing.s4),
            _Labeled(
              label: l10n.productAtHome,
              child: QuantityStepper(
                value: item.quantityLabel,
                unit: l10n.unitPackages,
                valueSpoken: l10n.stockAtHomeSpoken(item.quantity, item.quantityLabel),
                decrementLabel: l10n.stockOneLess,
                incrementLabel: l10n.stockOneMore,
                highlighted: item.isLow,
                onIncrement: () => _adjust(context, ref, 1),
                onDecrement: item.isOut ? null : () => _adjust(context, ref, -1),
              ),
            ),
            const SizedBox(height: BipaSpacing.s3),
            _Labeled(
              label: l10n.stockSheetTarget,
              hint: l10n.stockSheetTargetHelp,
              child: QuantityStepper(
                value: target == null ? l10n.stockTargetNone : Formatters.quantity(target),
                unit: l10n.unitPackages,
                valueSpoken: target == null
                    ? l10n.stockTargetNoneSpoken
                    : l10n.stockTargetSpoken(target, Formatters.quantity(target)),
                decrementLabel: l10n.stockTargetLess,
                incrementLabel: l10n.stockTargetMore,
                onIncrement: () => _setTarget(context, ref, (target ?? 0) + 1),
                onDecrement: target == null ? null : () => _setTarget(context, ref, target <= 1 ? null : target - 1),
              ),
            ),
            const SizedBox(height: BipaSpacing.s4),
            FilledButton.tonalIcon(
              onPressed: () => _toggleList(ref, onList: onList),
              icon: Icon(onList ? Icons.playlist_remove_rounded : Icons.playlist_add_rounded),
              label: Text(onList ? l10n.listRemoveFromList : l10n.listAddToList),
            ),
            const SizedBox(height: BipaSpacing.s4),
            Text(l10n.stockSheetWhere, style: BipaText.label.copyWith(color: colors.inkMuted)),
            const SizedBox(height: BipaSpacing.s2),
            Wrap(
              spacing: BipaSpacing.s2,
              runSpacing: BipaSpacing.s2,
              children: [
                for (final location in StockLocation.values)
                  ChoiceChip(
                    label: Text(location.localizedLabel(l10n)),
                    selected: item.location == location,
                    onSelected: (_) => _setLocation(context, ref, location),
                  ),
              ],
            ),
            const SizedBox(height: BipaSpacing.s4),
            // Wrap: com letra grande, os dois botões descem para linhas
            // separadas em vez de estourar a linha (H3).
            Wrap(
              alignment: entry == null ? WrapAlignment.end : WrapAlignment.spaceBetween,
              children: [
                if (entry != null) TextButton(onPressed: () => _remove(context, ref), child: Text(l10n.stockRemove)),
                if (!fromProduct)
                  TextButton(
                    onPressed: () {
                      final router = GoRouter.of(context);
                      Navigator.of(context).pop();
                      router.push(Routes.productDetail(product.id));
                    },
                    child: Text(l10n.stockSheetSeeProduct),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Um controle com o nome à esquerda e, embaixo do nome, uma explicação.
class _Labeled extends StatelessWidget {
  const _Labeled({required this.label, required this.child, this.hint});

  final String label;
  final String? hint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hint = this.hint;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: BipaText.bodyLarge.copyWith(color: colors.ink)),
              if (hint != null) Text(hint, style: BipaText.caption.copyWith(color: colors.inkMuted)),
            ],
          ),
        ),
        const SizedBox(width: BipaSpacing.s3),
        child,
      ],
    );
  }
}
