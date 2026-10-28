import 'package:bipa/core/catalog/product_kind.dart';
import 'package:bipa/core/design_system/bipa_metrics.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/design_system/bipa_typography.dart';
import 'package:bipa/core/design_system/components/price_rows.dart';
import 'package:bipa/core/design_system/components/product_category_icon.dart';
import 'package:bipa/core/design_system/components/section_header.dart';
import 'package:bipa/core/di/core_providers.dart';
import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/core/navigation/routes.dart';
import 'package:bipa/core/widgets/async_value_view.dart';
import 'package:bipa/core/widgets/empty_state.dart';
import 'package:bipa/features/markets/domain/nearest_market_finder.dart';
import 'package:bipa/features/markets/presentation/market_meta.dart';
import 'package:bipa/features/markets/presentation/markets_providers.dart';
import 'package:bipa/features/prices/domain/market_price.dart';
import 'package:bipa/features/prices/presentation/prices_providers.dart';
import 'package:bipa/features/shopping_list/domain/aisle_order.dart';
import 'package:bipa/features/shopping_list/presentation/aisle_label.dart';
import 'package:bipa/features/shopping_list/presentation/shopping_list_providers.dart';
import 'package:bipa/features/shopping_list/presentation/start_shopping.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Tela do mercado (protótipo "Mercado"): onde fica e a idade dos preços, a
/// ordem das seções aprendida nas compras (ADR 0014), o preço mais recente
/// de cada produto ali e "Ir às compras aqui".
class MarketPage extends ConsumerWidget {
  const MarketPage({required this.marketId, super.key});

  final String marketId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ranked = ref.watch(rankedMarketsProvider);
    // Depois de "Apagar", o mercado some enquanto a tela ainda sai de cena:
    // ela fica em branco em vez de avisar que ele não existe.
    final leaving = !(ModalRoute.of(context)?.isCurrent ?? true);

    return Material(
      color: context.colors.ground,
      child: AsyncValueView(
        value: ranked,
        data: (ranked) => switch (ranked.where((item) => item.market.id == marketId).firstOrNull) {
          final item? => _MarketView(item: item),
          null when leaving => const SizedBox.expand(),
          null => Scaffold(
            appBar: AppBar(),
            body: EmptyState(icon: Icons.search_off, message: AppLocalizations.of(context).marketNotFound),
          ),
        },
      ),
    );
  }
}

class _MarketView extends ConsumerWidget {
  const _MarketView({required this.item});

  final RankedMarket item;

  /// "Apagar": confirma dizendo o que vai junto (ADR 0016).
  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final market = item.market;
    final repository = ref.read(marketRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.marketDeleteTitle(market.name)),
        content: Text(l10n.marketDeleteBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l10n.marketDelete)),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    // Sai da tela antes de apagar: ela não chega a mostrar o mercado sumindo.
    context.pop();
    try {
      await repository.delete(market.id);
    } on Exception {
      messenger.showSnackBar(SnackBar(content: Text(l10n.marketDeleteFailed)));
    }
  }

  /// A compra começa já neste mercado, como se ele fosse escolhido no chip
  /// da lista.
  Future<void> _goShopping(BuildContext context, WidgetRef ref) {
    ref.read(listChosenMarketProvider.notifier).choose(item.market.id);
    return startShopping(context, ref);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final market = item.market;
    final isHere = ref.watch(nearestMarketFinderProvider).isInside(item);
    final latestPrice = (ref.watch(latestPricePerMarketProvider).value ?? const <String, DateTime>{})[market.id];
    final now = ref.watch(clockProvider)();
    final order = ref.watch(marketAisleOrderProvider(market.id)).value ?? AisleOrder.empty;
    final prices = ref.watch(marketPricesProvider(market.id)).value ?? const <MarketPrice>[];
    // Durante uma compra, "Ir às compras aqui" não tem o que começar.
    final shopping = ref.watch(activeTripProvider).value != null;
    final aisles = order.sort(order.learned.keys.where((aisle) => aisle != Aisle.other));
    final bottom = MediaQuery.paddingOf(context).bottom;
    final roundButton = IconButton.styleFrom(
      backgroundColor: colors.surface,
      foregroundColor: colors.ink,
      fixedSize: const Size.square(48),
    );
    final metaIcon = marketMetaIcon(item, isHere: isHere);

    return Scaffold(
      backgroundColor: colors.ground,
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.fromLTRB(
              BipaSpacing.s4,
              MediaQuery.paddingOf(context).top + BipaSpacing.s4,
              BipaSpacing.s4,
              bottom + (shopping ? BipaSpacing.s8 : 96),
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
                        value: () => context.push(Routes.editMarket(market.id)),
                        child: Text(l10n.marketEdit),
                      ),
                      PopupMenuItem(
                        value: () => _delete(context, ref),
                        child: Text(l10n.marketDelete),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: BipaSpacing.s4),
              Center(
                child: ExcludeSemantics(
                  child: Container(
                    width: 132,
                    height: 132,
                    decoration: BoxDecoration(
                      color: colors.placeSoft,
                      borderRadius: BorderRadius.circular(BipaRadius.lg),
                    ),
                    child: Icon(Icons.storefront_outlined, size: 56, color: colors.place),
                  ),
                ),
              ),
              const SizedBox(height: BipaSpacing.s3),
              Semantics(
                header: true,
                child: Text(
                  market.name,
                  textAlign: TextAlign.center,
                  style: BipaText.headline.copyWith(fontSize: 24, color: colors.ink),
                ),
              ),
              const SizedBox(height: BipaSpacing.s1),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (metaIcon != null) ...[
                    Icon(metaIcon, size: 16, color: colors.inkMuted),
                    const SizedBox(width: BipaSpacing.s1),
                  ],
                  Flexible(
                    child: Text(
                      marketMeta(l10n, item, isHere: isHere, latestPrice: latestPrice, now: now),
                      textAlign: TextAlign.center,
                      style: BipaText.body.copyWith(color: colors.inkMuted),
                    ),
                  ),
                ],
              ),
              // Sem compras aqui ainda, não há ordem para mostrar.
              if (aisles.length > 1) ...[
                const SizedBox(height: BipaSpacing.s6),
                SectionHeader(title: l10n.marketAisleOrder),
                const SizedBox(height: BipaSpacing.s2),
                _AisleSteps(labels: [for (final aisle in aisles) aisle.localizedLabel(l10n)]),
              ],
              if (prices.isNotEmpty) ...[
                const SizedBox(height: BipaSpacing.s6),
                SectionHeader(title: l10n.marketRecentPrices, count: prices.length),
                const SizedBox(height: BipaSpacing.s2),
                PriceRowList(
                  rows: [
                    for (final price in prices)
                      PriceRowData(
                        icon: productCategoryIcon(price.productName),
                        title: _title(price),
                        meta: l10n.priceAge(_ageInDays(now, price)),
                        metaIcon: Icons.schedule_rounded,
                        value: price.observation.price.format(),
                        onTap: () => context.push(Routes.productDetail(price.observation.productId)),
                      ),
                  ],
                ),
              ],
            ],
          ),
          if (!shopping)
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
                onPressed: () => _goShopping(context, ref),
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: Text(l10n.marketGoShoppingHere),
              ),
            ),
        ],
      ),
    );
  }

  /// "Arroz branco Camil 10 kg": o produto e, quando há, a marca e o tamanho
  /// da embalagem, como na etiqueta.
  static String _title(MarketPrice price) {
    final package = price.package;
    return [price.productName, ?package?.brand, ?package?.sizeLabel].join(' ');
  }

  /// Em dias do calendário, como na tela do produto.
  static int _ageInDays(DateTime now, MarketPrice price) =>
      DateUtils.dateOnly(now).difference(DateUtils.dateOnly(price.observation.observedAt)).inDays;
}

/// As seções na ordem do percurso, numeradas.
class _AisleSteps extends StatelessWidget {
  const _AisleSteps({required this.labels});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(BipaRadius.lg)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: BipaSpacing.s4, vertical: BipaSpacing.s3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (index, label) in labels.indexed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: BipaSpacing.s1),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: colors.surfaceSunken, shape: BoxShape.circle),
                      child: Text(
                        '${index + 1}',
                        style: BipaText.caption.copyWith(color: colors.inkMuted, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: BipaSpacing.s3),
                    Expanded(child: Text(label, style: BipaText.bodyLarge.copyWith(color: colors.ink))),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
