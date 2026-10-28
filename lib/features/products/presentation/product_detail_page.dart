import 'dart:async';

import 'package:bipa/core/design_system/bipa_metrics.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/design_system/bipa_typography.dart';
import 'package:bipa/core/design_system/components/price_history.dart';
import 'package:bipa/core/design_system/components/price_rows.dart';
import 'package:bipa/core/design_system/components/price_tag.dart';
import 'package:bipa/core/design_system/components/product_category_icon.dart';
import 'package:bipa/core/design_system/components/product_thumb.dart';
import 'package:bipa/core/design_system/components/quantity_stepper.dart';
import 'package:bipa/core/design_system/components/section_header.dart';
import 'package:bipa/core/di/core_providers.dart';
import 'package:bipa/core/formatting/formatters.dart';
import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/core/navigation/routes.dart';
import 'package:bipa/core/widgets/async_value_view.dart';
import 'package:bipa/core/widgets/empty_state.dart';
import 'package:bipa/features/prices/domain/package_prices.dart';
import 'package:bipa/features/prices/domain/price_trend.dart';
import 'package:bipa/features/prices/presentation/prices_providers.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/products/domain/product_package.dart';
import 'package:bipa/features/products/presentation/product_photos.dart';
import 'package:bipa/features/products/presentation/product_picker_sheet.dart';
import 'package:bipa/features/products/presentation/products_providers.dart';
import 'package:bipa/features/shopping_list/presentation/shopping_list_providers.dart';
import 'package:bipa/features/stock/domain/stock_item.dart';
import 'package:bipa/features/stock/domain/stock_movement_reason.dart';
import 'package:bipa/features/stock/domain/stock_lot.dart';
import 'package:bipa/features/stock/presentation/stock_item_sheet.dart';
import 'package:bipa/features/stock/presentation/stock_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Tela do produto (protótipo "Produto com embalagens", ADR 0013): o melhor
/// preço por kg, as embalagens com o preço de cada uma, o melhor preço em
/// cada mercado e quanto há em casa.
class ProductDetailPage extends ConsumerWidget {
  const ProductDetailPage({required this.productId, super.key});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = ref.watch(productProvider(productId));
    // Depois do "Juntar com…", o produto some enquanto esta tela ainda sai de
    // cena: ela fica em branco em vez de avisar que ele não existe.
    final leaving = !(ModalRoute.of(context)?.isCurrent ?? true);

    // Material garante tema e tipografia durante o carregamento, antes do Scaffold.
    return Material(
      color: context.colors.ground,
      child: AsyncValueView(
        value: product,
        data: (product) => switch (product) {
          final product? => _ProductView(product: product),
          null when leaving => const SizedBox.expand(),
          null => Scaffold(
            appBar: AppBar(),
            body: EmptyState(icon: Icons.search_off, message: AppLocalizations.of(context).productNotFound),
          ),
        },
      ),
    );
  }
}

/// Uma linha de "Embalagens": a embalagem e o preço mais recente dela.
typedef _PackageRow = ({ProductPackage package, PackagePrice? price});

class _ProductView extends ConsumerWidget {
  const _ProductView({required this.product});

  final Product product;

  Future<void> _adjust(WidgetRef ref, double delta) async {
    await ref
        .read(stockRepositoryProvider)
        .adjust(
          productId: product.id,
          delta: delta,
          reason: delta > 0 ? StockMovementReason.purchase : StockMovementReason.consumption,
        );
  }

  /// "Juntar com…": escolhe o outro produto, confirma e abre o que ficou.
  Future<void> _merge(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final repository = ref.read(productRepositoryProvider);
    final choice = await pickProduct(context, allowCreate: false, excludeId: product.id, title: l10n.productMerge);
    if (choice is! ExistingProduct || !context.mounted) return;
    final into = choice.product;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.productMergeTitle(into.name)),
        content: Text(l10n.productMergeBody(product.name, into.name)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l10n.productMergeConfirm)),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    // Abre o produto que fica antes de juntar: esta tela sai sem depender do
    // contexto depois do await. O aviso de falha usa o ScaffoldMessenger do
    // app, que continua lá.
    final messenger = ScaffoldMessenger.of(context);
    unawaited(GoRouter.of(context).pushReplacement<void>(Routes.productDetail(into.id)));
    try {
      await repository.merge(fromId: product.id, intoId: into.id);
      messenger.showSnackBar(SnackBar(content: Text(l10n.productMerged(product.name, into.name))));
    } on Exception {
      messenger.showSnackBar(SnackBar(content: Text(l10n.productMergeFailed)));
    }
  }

  /// "Apagar produto": confirma dizendo o que vai junto (ADR 0016).
  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final repository = ref.read(productRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.productDeleteTitle(product.name)),
        content: Text(l10n.productDeleteBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l10n.productDelete)),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    // Sai da tela antes de apagar: ela não chega a mostrar o produto sumindo.
    context.pop();
    try {
      await repository.delete(product.id);
    } on Exception {
      messenger.showSnackBar(SnackBar(content: Text(l10n.productDeleteFailed)));
    }
  }

  Future<void> _toggleList(WidgetRef ref, {required bool onList}) => onList
      ? ref.read(shoppingListRepositoryProvider).removeProduct(product.id)
      : ref.read(putProductOnListProvider)(product);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final packages = ref.watch(productPackagesProvider(product.id)).value ?? const <ProductPackage>[];
    final history = ref.watch(priceHistoryProvider(product.id)).value ?? const [];
    final stock = ref.watch(stockProvider).value?.where((e) => e.item.productId == product.id).firstOrNull;
    final amount = homeAmount(ref.watch(stockLotsProvider(product.id)).value ?? const <StockLot>[]);
    final onList = ref.watch(productsOnListProvider).contains(product.id);
    final photos = ref.watch(productPhotosDirectoryProvider).value;
    final now = ref.watch(clockProvider)();

    final perPackage = latestPricePerPackage(history, packages);
    final perMarket = bestPricePerMarket(history, packages);
    final priced = {for (final price in perPackage) price.package?.id};
    // As embalagens com preço, da mais barata por kg, e depois as sem preço.
    final packageRows = <_PackageRow>[
      for (final price in perPackage)
        if (price.package case final package?) (package: package, price: price),
      for (final package in packages)
        if (!priced.contains(package.id)) (package: package, price: null),
    ];
    final best = perPackage.firstOrNull;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final roundButton = IconButton.styleFrom(
      backgroundColor: colors.surface,
      foregroundColor: colors.ink,
      fixedSize: const Size.square(48),
    );

    return Scaffold(
      backgroundColor: colors.ground,
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.fromLTRB(
              BipaSpacing.s4,
              MediaQuery.paddingOf(context).top + BipaSpacing.s4,
              BipaSpacing.s4,
              bottom + 96,
            ),
            children: [
              Row(
                children: [
                  IconButton.filled(
                    tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                    style: roundButton,
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                  ),
                  const Spacer(),
                  PopupMenuButton<VoidCallback>(
                    tooltip: l10n.productMoreOptions,
                    style: roundButton,
                    icon: const Icon(Icons.more_horiz_rounded),
                    onSelected: (action) => action(),
                    // As ações usam o contexto da tela: o do menu some quando ele fecha.
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: () => context.push(Routes.editProduct(product.id)),
                        child: Text(l10n.productEdit),
                      ),
                      PopupMenuItem(
                        value: () => context.push(Routes.capturePriceFor(product.id)),
                        child: Text(l10n.productRegisterPrice),
                      ),
                      PopupMenuItem(
                        value: () => _merge(context, ref),
                        child: Text(l10n.productMerge),
                      ),
                      PopupMenuItem(
                        value: () => _delete(context, ref),
                        child: Text(l10n.productDelete),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: BipaSpacing.s4),
              Center(
                child: ProductThumb(
                  fallbackIcon: productCategoryIcon(product.name),
                  photo: productPhotoFile(product, photos),
                  size: 132,
                  radius: BipaRadius.lg,
                ),
              ),
              const SizedBox(height: BipaSpacing.s3),
              Text(
                product.name,
                textAlign: TextAlign.center,
                style: BipaText.headline.copyWith(fontSize: 24, color: colors.ink),
              ),
              if (best != null) ...[
                const SizedBox(height: BipaSpacing.s3),
                Center(child: _BestPrice(best: best)),
              ],
              if (packageRows.isNotEmpty) ...[
                const SizedBox(height: BipaSpacing.s6),
                SectionHeader(title: l10n.productPackages, count: packages.length),
                const SizedBox(height: BipaSpacing.s2),
                PriceRowList(
                  rows: [
                    for (final (index, row) in packageRows.indexed)
                      PriceRowData(
                        icon: Icons.inventory_2_outlined,
                        title: row.package.label ?? row.package.barcode ?? l10n.packageTitle,
                        meta: row.price?.unitPrice?.format(),
                        value: row.price?.price.format() ?? l10n.productNoPriceShort,
                        // Registrar o preço desta embalagem.
                        onTap: () => context.push(Routes.capturePriceFor(product.id, packageId: row.package.id)),
                        badge: _cheapestPerUnit(l10n, row.price, isFirst: index == 0 && perPackage.length > 1),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: BipaSpacing.s6),
              if (perMarket.isEmpty)
                Text(
                  l10n.productNoPrices,
                  textAlign: TextAlign.center,
                  style: BipaText.body.copyWith(color: colors.inkMuted),
                )
              else ...[
                SectionHeader(title: l10n.productMarkets, count: perMarket.length),
                const SizedBox(height: BipaSpacing.s2),
                PriceRowList(
                  rows: [
                    for (final (index, price) in perMarket.indexed)
                      PriceRowData(
                        icon: Icons.storefront_outlined,
                        title: price.entry.marketName,
                        meta: l10n.priceAge(_ageInDays(now, price)),
                        // A idade fica em cinza: o coral é só do estoque abaixo
                        // do "ter sempre".
                        metaIcon: Icons.schedule_rounded,
                        value: price.unitPrice?.format() ?? price.price.format(),
                        badge: index == 0 && perMarket.length > 1 ? l10n.productCheapest : null,
                      ),
                  ],
                ),
              ],
              if (priceTrend(history, packages, now: now) case final trend?) ...[
                const SizedBox(height: BipaSpacing.s6),
                SectionHeader(title: l10n.productHistory),
                const SizedBox(height: BipaSpacing.s2),
                _PriceHistory(trend: trend),
              ],
              const SizedBox(height: BipaSpacing.s6),
              SectionHeader(title: l10n.productAtHome),
              const SizedBox(height: BipaSpacing.s2),
              _AtHomeCard(
                stock: stock,
                onTap: () => showStockItemSheet(context, product, fromProduct: true),
                amount: amount == null ? null : l10n.measureAmount(Formatters.quantity(amount.amount), amount.unit.symbol),
                onIncrement: () => _adjust(ref, 1),
                onDecrement: (stock?.item.quantity ?? 0) > 0 ? () => _adjust(ref, -1) : null,
              ),
            ],
          ),
          Positioned(
            left: BipaSpacing.s4,
            right: BipaSpacing.s4,
            bottom: bottom + BipaSpacing.s4,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: colors.ink,
                foregroundColor: colors.surface,
                minimumSize: const Size.fromHeight(56),
              ),
              onPressed: () => _toggleList(ref, onList: onList),
              icon: Icon(onList ? Icons.playlist_remove_rounded : Icons.playlist_add_rounded),
              label: Text(onList ? l10n.listRemoveFromList : l10n.listAddToList),
            ),
          ),
        ],
      ),
    );
  }

  /// Em dias do calendário: um preço de ontem à noite visto hoje cedo é de
  /// "ontem", não de "hoje".
  static int _ageInDays(DateTime now, PackagePrice price) =>
      DateUtils.dateOnly(now).difference(DateUtils.dateOnly(price.entry.observation.observedAt)).inDays;

  /// "menor por kg", só para a primeira de várias, quando ela tem tamanho.
  static String? _cheapestPerUnit(AppLocalizations l10n, PackagePrice? price, {required bool isFirst}) {
    final unitPrice = price?.unitPrice;
    return isFirst && unitPrice != null ? l10n.productCheapestPerUnit(unitPrice.unit.symbol) : null;
  }
}

/// A etiqueta do melhor preço: por kg, quando a embalagem tem tamanho.
class _BestPrice extends StatelessWidget {
  const _BestPrice({required this.best});

  final PackagePrice best;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final unitPrice = best.unitPrice;
    final label = best.package?.label;
    if (unitPrice == null) return PriceTagHero(price: best.price, unitLine: label);
    return PriceTagHero(
      price: unitPrice.price,
      unitLine: label == null
          ? l10n.productUnitPriceOnly(unitPrice.unit.symbol)
          : l10n.productBestUnitPrice(unitPrice.unit.symbol, label),
    );
  }
}

/// "Últimos 6 meses": o menor preço de cada dia, por kg quando dá.
class _PriceHistory extends StatelessWidget {
  const _PriceHistory({required this.trend});

  final PriceTrend trend;

  /// Um rótulo a cada dois meses a partir do primeiro, no começo do mês, e
  /// "hoje" na ponta.
  static List<({String label, double at})> _axisLabels(PriceTrend trend, AppLocalizations l10n) {
    final month = DateFormat.MMM(l10n.localeName);
    final from = trend.from;
    final to = trend.to;
    final span = to.difference(from).inMilliseconds;
    final months = (to.year - from.year) * 12 + to.month - from.month;
    return [
      for (var offset = 0; offset < months; offset += 2)
        (
          // "mai." vira "mai", como no protótipo.
          label: month.format(DateTime(from.year, from.month + offset)).replaceAll('.', ''),
          at: DateTime(from.year, from.month + offset).difference(from).inMilliseconds / span,
        ),
      (label: l10n.productHistoryToday, at: 1.0),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final from = trend.from.millisecondsSinceEpoch;
    final span = trend.to.difference(trend.from).inMilliseconds.clamp(1, 1 << 52);
    final lowest = trend.lowest.cents;
    final range = trend.highest.cents - lowest;
    final first = trend.points.first.price.format();
    final last = trend.points.last.price.format();
    return PriceHistoryChart(
      points: [
        for (final point in trend.points)
          Offset(
            (point.day.millisecondsSinceEpoch - from) / span,
            range == 0 ? 0.5 : (point.price.cents - lowest) / range,
          ),
      ],
      axisLabels: _axisLabels(trend, l10n),
      semanticsLabel: switch (trend.unit) {
        final unit? => l10n.productHistoryLabel(unit.symbol, first, last),
        null => l10n.productHistoryLabelNoUnit(first, last),
      },
    );
  }
}

/// "Em casa": quanto há (o stepper) e o "ter sempre"; tocar abre os ajustes.
class _AtHomeCard extends StatelessWidget {
  const _AtHomeCard({
    required this.stock,
    required this.onTap,
    required this.onIncrement,
    this.amount,
    this.onDecrement,
  });

  final StockEntry? stock;

  /// Abre o editor do item, mesmo sem nada em casa: é onde se define o "ter
  /// sempre".
  final VoidCallback onTap;

  /// O total das embalagens em casa: "15 kg".
  final String? amount;
  final VoidCallback onIncrement;
  final VoidCallback? onDecrement;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final stock = this.stock;
    final target = stock?.item.targetQuantity;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(BipaRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(BipaRadius.lg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(BipaSpacing.s4, BipaSpacing.s3, BipaSpacing.s3, BipaSpacing.s3),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // "Ter sempre —" quando não há meta: o traço e a seta dizem que
                    // dá para definir.
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            l10n.productTargetCount(target == null ? l10n.stockTargetNone : Formatters.quantity(target)),
                            style: BipaText.body.copyWith(color: colors.inkMuted),
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, size: 18, color: colors.inkMuted),
                      ],
                    ),
                    if (amount case final amount?)
                      Text(l10n.productAmountAtHome(amount), style: BipaText.bodyLarge.copyWith(color: colors.ink)),
                  ],
                ),
              ),
              QuantityStepper(
                value: Formatters.quantity(stock?.item.quantity ?? 0),
                unit: l10n.unitPackages,
                decrementLabel: l10n.stockUsedOne,
                incrementLabel: l10n.stockBoughtOne,
                onIncrement: onIncrement,
                onDecrement: onDecrement,
                highlighted: stock?.item.isLow ?? false,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
