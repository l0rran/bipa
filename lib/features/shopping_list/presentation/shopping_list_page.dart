import 'package:bipa/core/catalog/product_kind.dart';
import 'package:bipa/core/design_system/bipa_metrics.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/design_system/bipa_typography.dart';
import 'package:bipa/core/design_system/components/product_category_icon.dart';
import 'package:bipa/core/design_system/components/section_header.dart';
import 'package:bipa/core/design_system/components/shopping_list.dart';
import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/core/money/money.dart';
import 'package:bipa/core/navigation/routes.dart';
import 'package:bipa/core/widgets/async_value_view.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/products/presentation/product_photos.dart';
import 'package:bipa/features/products/presentation/products_providers.dart';
import 'package:bipa/features/shopping_list/domain/shopping_list_item.dart';
import 'package:bipa/features/shopping_list/domain/shopping_list_sections.dart';
import 'package:bipa/features/shopping_list/domain/shopping_trip.dart';
import 'package:bipa/features/shopping_list/presentation/finish_shopping.dart';
import 'package:bipa/features/shopping_list/presentation/list_preview.dart';
import 'package:bipa/features/shopping_list/presentation/shopping_list_providers.dart';
import 'package:bipa/features/shopping_list/presentation/start_shopping.dart';
import 'package:bipa/features/stock/domain/stock_item.dart';
import 'package:bipa/features/stock/presentation/stock_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// A lista de compras (protótipo "Lista"): o progresso, o campo de adicionar,
/// os itens de sempre e a lista agrupada pelas seções do mercado.
///
/// Fora de uma compra, o topo mostra a prévia com "Ir às compras"; durante a
/// compra, o progresso e "Terminei". Ainda não há ordem dos corredores
/// aprendida por mercado nem lista por foto ou voz (roadmap da fase 1).
class ShoppingListPage extends ConsumerStatefulWidget {
  const ShoppingListPage({super.key});

  @override
  ConsumerState<ShoppingListPage> createState() => _ShoppingListPageState();
}

class _ShoppingListPageState extends ConsumerState<ShoppingListPage> {
  final _input = TextEditingController();
  final _inputFocus = FocusNode();
  String _query = '';

  /// Itens que saíram por gesto e ainda não sumiram do banco: o Dismissible
  /// não pode continuar na árvore depois de dispensado.
  final _dismissed = <String>{};

  /// Evita o toque duplo em "Terminei".
  var _finishing = false;

  @override
  void dispose() {
    _input.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  Future<void> _addProduct(Product product) async {
    await ref.read(shoppingListRepositoryProvider).addProduct(productId: product.id, name: product.name);
    if (mounted) _clearInput();
  }

  /// Escreveu o nome de um produto cadastrado: usa o produto (que não
  /// duplica). Senão, entra como item escrito à mão.
  Future<void> _submit() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    final list = ref.read(shoppingListRepositoryProvider);
    final matches = await ref.read(productRepositoryProvider).watchAll(query: text).first;
    final exact = matches.where((p) => p.name.toLowerCase() == text.toLowerCase()).firstOrNull;
    if (exact != null) {
      await list.addProduct(productId: exact.id, name: exact.name);
    } else {
      await list.addCustom(text);
    }
    if (mounted) _clearInput();
  }

  void _clearInput() {
    _input.clear();
    setState(() => _query = '');
    _inputFocus.requestFocus();
  }

  Future<void> _toggleUsual(Product product, {required bool onList}) {
    final repository = ref.read(shoppingListRepositoryProvider);
    return onList
        ? repository.removeProduct(product.id)
        : repository.addProduct(productId: product.id, name: product.name);
  }

  Future<void> _remove(ShoppingListEntry entry) async {
    final repository = ref.read(shoppingListRepositoryProvider);
    setState(() => _dismissed.add(entry.item.id));
    await repository.remove(entry.item.id);
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.listItemRemoved(entry.name)),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: l10n.undo,
            onPressed: () {
              if (mounted) setState(() => _dismissed.remove(entry.item.id));
              repository.restore(entry.item);
            },
          ),
        ),
      );
  }

  Future<void> _finish(ShoppingTrip trip) async {
    setState(() => _finishing = true);
    try {
      await finishShopping(context, ref, trip.id);
    } finally {
      if (mounted) setState(() => _finishing = false);
    }
  }

  /// Marcar na lista durante a compra também decide se o item do carrinho
  /// vai ser levado: os dois lugares contam a mesma história.
  Future<void> _setChecked(ShoppingListEntry entry, {required bool checked}) async {
    final list = ref.read(shoppingListRepositoryProvider);
    final cart = ref.read(cartRepositoryProvider);
    final trip = ref.read(activeTripProvider).value;
    await list.setChecked(entry.item.id, checked: checked);
    final productId = entry.item.productId;
    if (trip != null && productId != null) {
      await cart.setTakeForProduct(trip.id, productId, take: checked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final list = ref.watch(shoppingListProvider);
    final trip = ref.watch(activeTripProvider).value;
    final tripSummary = ref.watch(shoppingTripSummaryProvider);
    final photos = ref.watch(productPhotosDirectoryProvider).value;
    final prices = ref.watch(shoppingListPricesProvider).value ?? const <String, Money>{};
    final summary = ref.watch(shoppingListSummaryProvider);
    final onList = ref.watch(productsOnListProvider);
    final usual = _usualProducts(ref.watch(stockProvider).value ?? const []);
    final query = _query.trim();
    final suggestions = query.isEmpty
        ? const <Product>[]
        : (ref.watch(listProductSuggestionsProvider(query)).value ?? const <Product>[])
              .where((p) => !onList.contains(p.id))
              .take(5)
              .toList();

    return Scaffold(
      body: AsyncValueView(
        value: list,
        data: (all) {
          // Os dispensados que o banco já apagou não precisam mais ser escondidos.
          _dismissed.removeWhere((id) => !all.any((e) => e.item.id == id));
          final entries = [for (final e in all) if (!_dismissed.contains(e.item.id)) e];
          final sections = shoppingListSections(entries);
          return CustomScrollView(
            slivers: [
              SliverSafeArea(
                bottom: false,
                sliver: SliverPadding(
                  padding: const EdgeInsets.fromLTRB(BipaSpacing.s4, BipaSpacing.s6, BipaSpacing.s4, 0),
                  sliver: SliverList.list(
                    children: [
                      Semantics(
                        header: true,
                        child: Text(l10n.listTitle, style: BipaText.headline.copyWith(color: context.colors.ink)),
                      ),
                      if (trip != null && tripSummary != null) ...[
                        const SizedBox(height: BipaSpacing.s4),
                        ShoppingProgress(
                          label: l10n.listProgress(tripSummary.done, tripSummary.total),
                          value: tripSummary.progress,
                          leading: tripSummary.spent?.format(),
                        ),
                        const SizedBox(height: BipaSpacing.s3),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => context.push(Routes.cartMode),
                              icon: const Icon(Icons.qr_code_scanner_rounded),
                              label: Text(l10n.cartTitle),
                            ),
                            const SizedBox(width: BipaSpacing.s2),
                            FilledButton(
                              onPressed: _finishing ? null : () => _finish(trip),
                              style: FilledButton.styleFrom(
                                backgroundColor: context.colors.ink,
                                foregroundColor: context.colors.surface,
                              ),
                              child: Text(l10n.tripFinish),
                            ),
                          ],
                        ),
                      ] else if (summary.remaining > 0) ...[
                        const SizedBox(height: BipaSpacing.s4),
                        ListPreview(
                          entries: entries,
                          summary: summary,
                          photos: photos,
                          onGoShopping: () => startShopping(context, ref),
                        ),
                      ],
                      const SizedBox(height: BipaSpacing.s4),
                      _AddField(
                        controller: _input,
                        focusNode: _inputFocus,
                        hint: l10n.listAddHint,
                        submitLabel: l10n.listAdd,
                        onChanged: (value) => setState(() => _query = value),
                        onSubmitted: _submit,
                      ),
                      for (final product in suggestions)
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: BipaSpacing.s2),
                          leading: Icon(productCategoryIcon(product.name), color: context.colors.ink),
                          title: Text(product.name, style: BipaText.bodyLarge.copyWith(color: context.colors.ink)),
                          trailing: Icon(Icons.add_rounded, color: context.colors.ink),
                          onTap: () => _addProduct(product),
                        ),
                    ],
                  ),
                ),
              ),
              if (usual.isNotEmpty) ...[
                _sectionHeader(SectionHeader(title: l10n.listUsual)),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 76,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: BipaSpacing.s4),
                      itemCount: usual.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final product = usual[index];
                        final selected = onList.contains(product.id);
                        return QuickTile(
                          icon: productCategoryIcon(product.name),
                          label: product.name,
                          selected: selected,
                          onTap: () => _toggleUsual(product, onList: selected),
                        );
                      },
                    ),
                  ),
                ),
              ],
              if (entries.isEmpty)
                SliverPadding(
                  padding: const EdgeInsets.all(BipaSpacing.s8),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      l10n.listEmpty,
                      textAlign: TextAlign.center,
                      style: BipaText.body.copyWith(color: context.colors.inkMuted),
                    ),
                  ),
                )
              else ...[
                _sectionHeader(
                  SectionHeader(
                    title: l10n.listInStore,
                    count: summary.total,
                    actionLabel: summary.done > 0 ? l10n.listRemoveChecked : null,
                    onAction: () => ref.read(shoppingListRepositoryProvider).removeChecked(),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: BipaSpacing.s4),
                  sliver: SliverList.separated(
                    itemCount: sections.length,
                    separatorBuilder: (_, _) => const SizedBox(height: BipaSpacing.s2),
                    itemBuilder: (context, index) {
                      final section = sections[index];
                      return ShoppingSectionCard(
                        title: section.aisle.localizedLabel(l10n),
                        progress: '${section.done}/${section.total}',
                        children: [
                          for (final entry in section.entries)
                            Dismissible(
                              key: ValueKey('list-${entry.item.id}'),
                              direction: DismissDirection.endToStart,
                              background: ColoredBox(
                                color: context.colors.surfaceSunken,
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: BipaSpacing.s4),
                                    child: Icon(Icons.delete_outline_rounded, color: context.colors.ink),
                                  ),
                                ),
                              ),
                              onDismissed: (_) => _remove(entry),
                              child: ShoppingListRow(
                                name: entry.name,
                                checked: entry.item.isChecked,
                                price: switch (entry.item.productId) {
                                  final id? when prices[id] != null => l10n.listEstimate(prices[id]!.formatDecimal()),
                                  _ => null,
                                },
                                onChanged: (checked) => _setChecked(entry, checked: checked),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ],
              // Espaço para as barras flutuantes (navegação e compra).
              SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).bottom + BipaSpacing.s4)),
            ],
          );
        },
      ),
    );
  }

  /// Os produtos que a pessoa quer ter sempre: os que estão acabando primeiro.
  List<Product> _usualProducts(List<StockEntry> stock) {
    final usual = stock.where((e) => e.item.targetQuantity != null).toList()
      ..sort((a, b) {
        final byLevel = a.item.fillFraction.compareTo(b.item.fillFraction);
        return byLevel != 0 ? byLevel : a.product.name.compareTo(b.product.name);
      });
    return [for (final entry in usual) entry.product];
  }

  Widget _sectionHeader(Widget header) => SliverPadding(
    padding: const EdgeInsets.fromLTRB(BipaSpacing.s4, BipaSpacing.s6, BipaSpacing.s4, BipaSpacing.s2),
    sliver: SliverToBoxAdapter(child: header),
  );
}

/// O campo "Adicionar item", em pílula, com o "+" que confirma.
class _AddField extends StatelessWidget {
  const _AddField({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.submitLabel,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final String submitLabel;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      height: 52,
      padding: const EdgeInsets.only(left: BipaSpacing.s4, right: 6),
      decoration: ShapeDecoration(color: colors.surface, shape: const StadiumBorder()),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              onSubmitted: (_) => onSubmitted(),
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              style: BipaText.bodyLarge.copyWith(fontWeight: FontWeight.w500, color: colors.ink),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: BipaText.bodyLarge.copyWith(fontWeight: FontWeight.w500, color: colors.inkMuted),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isDense: true,
              ),
            ),
          ),
          IconButton(
            tooltip: submitLabel,
            onPressed: onSubmitted,
            style: IconButton.styleFrom(backgroundColor: colors.surfaceSunken, foregroundColor: colors.ink),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}

extension AisleLabel on Aisle {
  String localizedLabel(AppLocalizations l10n) => switch (this) {
    Aisle.produce => l10n.aisleProduce,
    Aisle.bakery => l10n.aisleBakery,
    Aisle.meat => l10n.aisleMeat,
    Aisle.dairy => l10n.aisleDairy,
    Aisle.grocery => l10n.aisleGrocery,
    Aisle.sweets => l10n.aisleSweets,
    Aisle.frozen => l10n.aisleFrozen,
    Aisle.drinks => l10n.aisleDrinks,
    Aisle.cleaning => l10n.aisleCleaning,
    Aisle.hygiene => l10n.aisleHygiene,
    Aisle.pet => l10n.aislePet,
    Aisle.other => l10n.aisleOther,
  };
}
