import 'dart:io';

import 'package:bipa/core/design_system/bipa_metrics.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/design_system/bipa_typography.dart';
import 'package:bipa/core/design_system/components/bipa_search_bar.dart';
import 'package:bipa/core/design_system/components/place_filter.dart';
import 'package:bipa/core/design_system/components/product_card.dart';
import 'package:bipa/core/design_system/components/product_category_icon.dart';
import 'package:bipa/core/design_system/components/product_thumb.dart';
import 'package:bipa/core/design_system/components/quantity_stepper.dart';
import 'package:bipa/core/design_system/components/section_header.dart';
import 'package:bipa/core/design_system/components/stock_list.dart';
import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/core/navigation/routes.dart';
import 'package:bipa/core/widgets/async_value_view.dart';
import 'package:bipa/core/widgets/empty_state.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/products/presentation/product_photos.dart';
import 'package:bipa/features/products/presentation/scan_product.dart';
import 'package:bipa/features/stock/domain/stock_item.dart';
import 'package:bipa/features/stock/domain/stock_location.dart';
import 'package:bipa/features/stock/domain/stock_movement_reason.dart';
import 'package:bipa/features/stock/presentation/stock_display.dart';
import 'package:bipa/features/stock/presentation/stock_item_sheet.dart';
import 'package:bipa/features/stock/presentation/stock_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// A Casa: o que tem em casa, com a prateleira do que está acabando no topo.
///
/// Segue o protótipo "Casa" do design system: busca com bipar, locais como
/// categorias, a prateleira de "Acabando" e a lista com medidor de nível.
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  String _query = '';

  /// `null` mostra todos os locais.
  StockLocation? _place;

  /// Só uma linha fica aberta por vez.
  String? _expandedProductId;

  Future<void> _addByBarcode() async {
    final product = await scanAndResolveProduct(context, ref);
    if (product == null || !mounted) return;
    await _adjust(product, 1, undoable: true);
  }

  /// Soma [delta] ao estoque. Com [undoable], mostra o aviso com "Desfazer".
  Future<void> _adjust(Product product, double delta, {bool undoable = false}) async {
    final repository = ref.read(stockRepositoryProvider);
    await repository.adjust(
      productId: product.id,
      delta: delta,
      reason: delta > 0 ? StockMovementReason.purchase : StockMovementReason.consumption,
    );
    if (!undoable || !mounted) return;

    final l10n = AppLocalizations.of(context);
    final message = delta > 0 ? l10n.stockBoughtOneDone(product.name) : l10n.stockUsedOneDone(product.name);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: l10n.undo,
            onPressed: () => repository.adjust(
              productId: product.id,
              delta: -delta,
              reason: StockMovementReason.adjustment,
            ),
          ),
        ),
      );
  }

  List<StockEntry> _visible(List<StockEntry> entries) {
    final query = _query.trim().toLowerCase();
    return [
      for (final entry in entries)
        if ((_place == null || entry.item.location == _place) &&
            (query.isEmpty || entry.product.name.toLowerCase().contains(query)))
          entry,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final stock = ref.watch(stockProvider);
    final photos = ref.watch(productPhotosDirectoryProvider).value;

    return Scaffold(
      body: AsyncValueView(
        value: stock,
        data: (entries) {
          if (entries.isEmpty) {
            return EmptyState(
              icon: Icons.kitchen_outlined,
              message: l10n.homeEmpty,
              actionLabel: l10n.homeEmptyAction,
              onAction: _addByBarcode,
            );
          }

          final visible = _visible(entries);
          // Acabou primeiro, depois o que está mais perto de acabar.
          final low = visible.where((e) => e.item.isLow).toList()
            ..sort((a, b) => a.item.fillFraction.compareTo(b.item.fillFraction));
          final atHome = visible.where((e) => !e.item.isLow).toList();

          return CustomScrollView(
            slivers: [
              SliverSafeArea(
                bottom: false,
                sliver: SliverPadding(
                  padding: const EdgeInsets.fromLTRB(BipaSpacing.s4, BipaSpacing.s6, BipaSpacing.s4, 0),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(l10n.homeTitle, style: BipaText.headline.copyWith(color: context.colors.ink)),
                        ),
                        const SizedBox(height: BipaSpacing.s4),
                        BipaSearchBar(
                          hint: l10n.searchHome,
                          onChanged: (value) => setState(() => _query = value),
                          onScan: _addByBarcode,
                          scanLabel: l10n.searchScan,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: BipaSpacing.s6),
                  child: _PlaceFilter(entries: entries, selected: _place, onSelected: (p) => setState(() => _place = p)),
                ),
              ),
              if (visible.isEmpty)
                SliverPadding(
                  padding: const EdgeInsets.all(BipaSpacing.s8),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      l10n.homeNoResults,
                      textAlign: TextAlign.center,
                      style: BipaText.body.copyWith(color: context.colors.inkMuted),
                    ),
                  ),
                ),
              if (low.isNotEmpty) ...[
                _sectionHeader(SectionHeader(title: l10n.sectionRunningLow, count: low.length, alert: true)),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 172,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: BipaSpacing.s4),
                      itemCount: low.length,
                      separatorBuilder: (_, _) => const SizedBox(width: BipaSpacing.s3),
                      itemBuilder: (context, index) {
                        final entry = low[index];
                        return ProductCard(
                          name: entry.product.name,
                          image: _ProductArt(product: entry.product, photo: productPhotoFile(entry.product, photos)),
                          gauge: entry.item.gauge(l10n, size: 36),
                          onTap: () => context.push(Routes.productDetail(entry.product.id)),
                        );
                      },
                    ),
                  ),
                ),
              ],
              if (atHome.isNotEmpty) ...[
                _sectionHeader(SectionHeader(title: l10n.sectionAtHome, count: atHome.length)),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: BipaSpacing.s4),
                  sliver: SliverToBoxAdapter(
                    child: StockList(
                      children: [
                        for (final entry in atHome)
                          _HomeStockRow(
                            entry: entry,
                            photo: productPhotoFile(entry.product, photos),
                            expanded: _expandedProductId == entry.product.id,
                            onTap: () => setState(() {
                              final id = entry.product.id;
                              _expandedProductId = _expandedProductId == id ? null : id;
                            }),
                            onAdjust: (delta, {undoable = false}) => _adjust(entry.product, delta, undoable: undoable),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
              // Espaço para a barra de navegação flutuante.
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionHeader(Widget header) => SliverPadding(
    padding: const EdgeInsets.fromLTRB(BipaSpacing.s4, BipaSpacing.s6, BipaSpacing.s4, BipaSpacing.s2),
    sliver: SliverToBoxAdapter(child: header),
  );
}

class _PlaceFilter extends StatelessWidget {
  const _PlaceFilter({required this.entries, required this.selected, required this.onSelected});

  final List<StockEntry> entries;
  final StockLocation? selected;
  final ValueChanged<StockLocation?> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final counts = <StockLocation, int>{};
    for (final entry in entries) {
      counts.update(entry.item.location, (count) => count + 1, ifAbsent: () => 1);
    }
    // Os locais em uso, do que tem mais itens para o que tem menos.
    final places = counts.keys.toList()..sort((a, b) => counts[b]!.compareTo(counts[a]!));

    return PlaceFilter<StockLocation?>(
      selected: selected,
      onSelected: onSelected,
      options: [
        PlaceOption(value: null, label: l10n.placeAll, icon: Icons.grid_view_rounded, count: entries.length),
        for (final place in places)
          PlaceOption(value: place, label: place.localizedLabel(l10n), icon: place.icon, count: counts[place]!),
      ],
    );
  }
}

/// Arte do cartão de produto: a foto cobrindo o quadro ou o ícone da categoria.
class _ProductArt extends StatelessWidget {
  const _ProductArt({required this.product, required this.photo});

  final Product product;
  final File? photo;

  @override
  Widget build(BuildContext context) {
    final icon = Center(child: Icon(productCategoryIcon(product.name), size: 46, color: context.colors.ink));
    final file = photo;
    if (file == null) return icon;
    return Image.file(file, fit: BoxFit.cover, gaplessPlayback: true, errorBuilder: (_, _, _) => icon);
  }
}

typedef _Adjust = Future<void> Function(double delta, {bool undoable});

class _HomeStockRow extends StatelessWidget {
  const _HomeStockRow({
    required this.entry,
    required this.photo,
    required this.expanded,
    required this.onTap,
    required this.onAdjust,
  });

  final StockEntry entry;
  final File? photo;
  final bool expanded;
  final VoidCallback onTap;
  final _Adjust onAdjust;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final item = entry.item;
    final product = entry.product;

    return StockRow(
      id: product.id,
      thumb: ProductThumb(photo: photo, fallbackIcon: productCategoryIcon(product.name), dimmed: item.isOut),
      name: product.name,
      gauge: item.gauge(l10n),
      expanded: expanded,
      onTap: onTap,
      swipeLeft: item.isOut
          ? null
          : StockSwipeAction(
              label: l10n.stockUsedOne,
              icon: Icons.remove_rounded,
              onTriggered: () => onAdjust(-1, undoable: true),
            ),
      editor: StockRowEditor(
        stepper: QuantityStepper(
          value: item.quantityLabel,
          unit: l10n.unitPackages,
          decrementLabel: l10n.stockUsedOne,
          incrementLabel: l10n.stockBoughtOne,
          highlighted: item.isLow,
          onIncrement: () => onAdjust(1),
          onDecrement: item.isOut ? null : () => onAdjust(-1),
        ),
        trailing: IconButton(
          tooltip: l10n.stockSettings,
          onPressed: () => showStockItemSheet(context, entry),
          icon: const Icon(Icons.tune_rounded),
        ),
      ),
    );
  }
}
