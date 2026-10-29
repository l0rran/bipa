import 'package:bipa/core/design_system/bipa_metrics.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/design_system/bipa_typography.dart';
import 'package:bipa/core/design_system/components/bipa_toast.dart';
import 'package:bipa/core/design_system/components/error_line.dart';
import 'package:bipa/core/design_system/components/price_tag.dart';
import 'package:bipa/core/design_system/components/product_category_icon.dart';
import 'package:bipa/core/design_system/components/save_badge.dart';
import 'package:bipa/core/design_system/components/scan_tray.dart';
import 'package:bipa/core/design_system/components/tap_target.dart';
import 'package:bipa/core/formatting/formatters.dart';
import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/core/money/money.dart';
import 'package:bipa/core/widgets/price_dialog.dart';
import 'package:bipa/features/markets/domain/market.dart';
import 'package:bipa/features/prices/domain/price_comparison.dart';
import 'package:bipa/features/prices/domain/price_source.dart';
import 'package:bipa/features/prices/domain/price_tag.dart';
import 'package:bipa/features/prices/domain/register_price_observation.dart';
import 'package:bipa/features/prices/presentation/prices_providers.dart';
import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/products/domain/product_package.dart';
import 'package:bipa/features/products/presentation/product_picker_sheet.dart';
import 'package:bipa/features/shopping_list/domain/cart_item.dart';
import 'package:bipa/features/shopping_list/presentation/home_change_snack_bar.dart';
import 'package:bipa/features/shopping_list/presentation/shopping_list_providers.dart';
import 'package:bipa/features/stock/presentation/stock_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// O preço lido, para conferir antes de salvar.
typedef PriceToConfirm = ({
  Product product,
  ProductPackage? package,
  Money price,
  List<PriceOffer> otherOffers,
  PriceSource source,

  /// O preço é por quilo: granel, sem "Também comprei" (ADR 0018).
  bool perKilo,
});

/// O que a folha salvou: o produto e o preço podem ter sido trocados nela.
typedef SavedPrice = ({Product product, ProductPackage? package, Money price});

/// Abre a folha "Conferir e salvar" (protótipo "Confirmação"). Devolve o
/// que foi salvo, ou `null` se a pessoa fechou a folha. O mercado aparece
/// sob o produto e se troca ali, por [chooseMarket]; sem [market], é pedido
/// no "Salvar".
Future<SavedPrice?> showConfirmPriceSheet(
  BuildContext context, {
  required PriceToConfirm reading,
  required Market? market,
  required Future<Market?> Function() chooseMarket,
}) => showModalBottomSheet<SavedPrice>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => BipaSheetToasts(
    child: ConfirmPriceSheet(reading: reading, market: market, chooseMarket: chooseMarket),
  ),
);

/// A folha de conferir o preço: o produto (que dá para trocar), o preço em
/// destaque (com o lápis para corrigir), "Mais barato aqui" quando é o caso
/// e "Também comprei", que soma uma embalagem em casa.
class ConfirmPriceSheet extends ConsumerStatefulWidget {
  const ConfirmPriceSheet({required this.reading, required this.market, required this.chooseMarket, super.key});

  final PriceToConfirm reading;
  final Market? market;
  final Future<Market?> Function() chooseMarket;

  @override
  ConsumerState<ConfirmPriceSheet> createState() => _ConfirmPriceSheetState();
}

class _ConfirmPriceSheetState extends ConsumerState<ConfirmPriceSheet> {
  late Product _product = widget.reading.product;
  late ProductPackage? _package = widget.reading.package;
  late Money _price = widget.reading.price;
  late PriceSource _source = widget.reading.source;
  late Market? _market = widget.market;
  var _alsoBought = false;
  var _saving = false;
  String? _error;

  Future<void> _changeProduct() async {
    final title = AppLocalizations.of(context).confirmChangeProduct;
    final choice = await pickProduct(context, allowCreate: false, title: title);
    if (choice is! ExistingProduct || !mounted) return;
    setState(() {
      _product = choice.product;
      // A embalagem lida era de outro produto.
      _package = null;
    });
  }

  /// Tocou no mercado: o preço vai para o escolhido (D7).
  Future<void> _changeMarket() async {
    final market = await widget.chooseMarket();
    if (market != null && mounted) setState(() => _market = market);
  }

  Future<void> _editPrice() async {
    final l10n = AppLocalizations.of(context);
    final price = await showPriceDialog(context, title: l10n.confirmEditPrice, initial: _price);
    if (price == null || !mounted) return;
    setState(() {
      _price = price;
      _source = PriceSource.manual;
    });
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final register = ref.read(registerPriceObservationProvider);
    final record = ref.read(recordAtHomeProvider);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      // Sem mercado, ele é pedido aqui, no "Salvar" (protótipo "Captura").
      final market = _market ?? await widget.chooseMarket();
      if (market == null) {
        if (mounted) setState(() => _error = l10n.cartNeedMarket);
        return;
      }
      final marketId = market.id;
      final packageId = _package?.id;
      await register(
        RegisterPriceInput(
          marketId: marketId,
          productId: _product.id,
          packageId: packageId,
          price: _price,
          source: _source,
          // Corrigido à mão, os outros preços da etiqueta podem não valer mais.
          otherOffers: _source == PriceSource.priceTag ? widget.reading.otherOffers : const [],
        ),
      );
      // Como o "Comprei" da câmera: sai da lista, com "Desfazer".
      final bought = _alsoBought ? await record.bought(_product, packageId: packageId) : null;
      if (bought != null) {
        showHomeChangeSnackBar(messenger, l10n: l10n, record: record, product: _product, change: bought);
      }
      if (mounted) Navigator.of(context).pop<SavedPrice>((product: _product, package: _package, price: _price));
    } on Exception {
      if (mounted) setState(() => _error = l10n.capturePriceFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Quanto este preço fica abaixo do menor dos outros mercados, para a
  /// mesma embalagem; `null` se não fica. Sem a embalagem ou sem saber o
  /// mercado, a comparação não seria justa: não há selo.
  Money? _cheaperBy() {
    final marketId = _market?.id;
    final packageId = _package?.id;
    if (marketId == null || packageId == null) return null;
    final history = ref.watch(priceHistoryProvider(_product.id)).value ?? const [];
    final others = [
      for (final entry in latestPricePerMarket([
        for (final entry in history)
          if (entry.observation.packageId == packageId) entry,
      ]))
        if (entry.observation.marketId != marketId) entry.observation.price,
    ];
    if (others.isEmpty) return null;
    final cheapestOther = others.reduce((a, b) => a < b ? a : b);
    return cheapestOther > _price ? cheapestOther - _price : null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final package = _package;
    final barcode = package?.barcode;
    final unitPrice = package?.unitPrice(_price);
    final atHome = (ref.watch(stockProvider).value ?? const [])
        .where((entry) => entry.product.id == _product.id)
        .firstOrNull
        ?.item
        .quantity;
    final current = atHome ?? 0;
    final cheaperBy = _cheaperBy();
    final error = _error;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        BipaSpacing.s4,
        0,
        BipaSpacing.s4,
        BipaSpacing.s4 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: colors.surfaceSunken,
                  borderRadius: BorderRadius.circular(BipaRadius.md),
                ),
                child: Icon(productCategoryIcon(_product.name), size: 30, color: colors.ink),
              ),
              const SizedBox(width: BipaSpacing.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      CartEntry.nameOf(_product, package),
                      style: BipaText.bodyLarge.copyWith(fontWeight: FontWeight.w700, color: colors.ink),
                    ),
                    if (barcode != null)
                      Text(barcode, style: BipaText.barcode.copyWith(fontSize: 13, color: colors.inkMuted)),
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: l10n.confirmChangeProduct,
                onPressed: _changeProduct,
                icon: const Icon(Icons.swap_horiz_rounded),
              ),
            ],
          ),
          // Onde o preço vai cair, à vista e trocável (D7): sem destaque, que
          // o destaque da folha é o preço.
          const SizedBox(height: BipaSpacing.s2),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TapTarget(
              onTap: _changeMarket,
              child: Semantics(
                button: true,
                onTap: _changeMarket,
                label: switch (_market) {
                  final market? => l10n.confirmMarketLabel(market.name),
                  null => l10n.cartChooseMarket,
                },
                excludeSemantics: true,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.storefront_outlined, size: 18, color: colors.inkMuted),
                    const SizedBox(width: BipaSpacing.s1),
                    Flexible(
                      child: Text(
                        _market?.name ?? l10n.cartChooseMarket,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: BipaText.body.copyWith(color: colors.inkMuted),
                      ),
                    ),
                    Icon(Icons.expand_more_rounded, size: 18, color: colors.inkMuted),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: BipaSpacing.s4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Flexível: com letra grande, a etiqueta encolhe antes de passar da tela.
              Flexible(
                child: PriceTagHero(
                  price: _price,
                  unitLine: widget.reading.perKilo
                      ? l10n.productUnitPriceOnly(MeasureUnit.kilogram.symbol)
                      : unitPrice?.format(),
                ),
              ),
              const SizedBox(width: BipaSpacing.s3),
              IconButton.filledTonal(
                tooltip: l10n.confirmEditPrice,
                onPressed: _editPrice,
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
          if (cheaperBy != null) ...[
            const SizedBox(height: BipaSpacing.s4),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: SaveBadge(label: l10n.confirmCheaperHere(cheaperBy.format())),
            ),
          ],
          // No granel, o que vai para casa depende do peso: sem "Também comprei".
          if (!widget.reading.perKilo) ...[
            const SizedBox(height: BipaSpacing.s4),
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surfaceSunken,
                borderRadius: BorderRadius.circular(BipaRadius.md),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(BipaSpacing.s4, BipaSpacing.s2, BipaSpacing.s2, BipaSpacing.s2),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.confirmAlsoBought, style: BipaText.bodyLarge.copyWith(color: colors.ink)),
                          Text(
                            _alsoBought
                                ? l10n.confirmAtHomeAfter(
                                    Formatters.quantity(current),
                                    Formatters.quantity(current + 1),
                                  )
                                : l10n.confirmAtHome(Formatters.quantity(current)),
                            style: BipaText.body.copyWith(fontSize: 13, color: colors.inkMuted),
                          ),
                        ],
                      ),
                    ),
                    BipaToggle(
                      value: _alsoBought,
                      semanticLabel: l10n.confirmAlsoBought,
                      onChanged: (value) => setState(() => _alsoBought = value),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (error != null) ...[const SizedBox(height: BipaSpacing.s3), ErrorLine(error)],
          const SizedBox(height: BipaSpacing.s4),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
            onPressed: _saving ? null : _save,
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }
}
