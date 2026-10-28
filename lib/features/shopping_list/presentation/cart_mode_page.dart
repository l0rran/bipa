import 'dart:async';

import 'package:bipa/core/design_system/bipa_metrics.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/design_system/bipa_typography.dart';
import 'package:bipa/core/design_system/components/scan_tray.dart';
import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/core/money/money.dart';
import 'package:bipa/core/navigation/routes.dart';
import 'package:bipa/features/markets/presentation/market_picker_sheet.dart';
import 'package:bipa/features/prices/domain/price_comparison.dart';
import 'package:bipa/features/prices/domain/price_source.dart';
import 'package:bipa/features/prices/domain/register_price_observation.dart';
import 'package:bipa/features/prices/presentation/prices_providers.dart';
import 'package:bipa/features/products/domain/gtin.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/products/presentation/product_form_page.dart';
import 'package:bipa/features/products/presentation/products_providers.dart';
import 'package:bipa/features/shopping_list/domain/cart_item.dart';
import 'package:bipa/features/shopping_list/domain/shopping_trip.dart';
import 'package:bipa/features/shopping_list/presentation/finish_shopping.dart';
import 'package:bipa/features/shopping_list/presentation/shopping_list_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Modo carrinho (protótipo "Modo carrinho"): a câmera fica aberta e cada
/// código lido entra na bandeja com o último preço daquele mercado. O disparo
/// fotografa a etiqueta, e o preço lido também entra no carrinho.
class CartModePage extends ConsumerStatefulWidget {
  const CartModePage({super.key});

  @override
  ConsumerState<CartModePage> createState() => _CartModePageState();
}

class _CartModePageState extends ConsumerState<CartModePage> {
  final _scanner = MobileScannerController(
    formats: const [BarcodeFormat.ean13, BarcodeFormat.ean8, BarcodeFormat.upcA, BarcodeFormat.upcE],
  );

  /// Quando cada código foi lido pela última vez: a câmera lê o mesmo código
  /// várias vezes por segundo, e bipar de novo só vale depois de uma pausa.
  final _lastSeen = <String, DateTime>{};
  static const _rescanPause = Duration(milliseconds: 2500);

  /// A moldura "trava" por um instante a cada item bipado.
  var _locked = false;
  Timer? _unlock;
  var _finishing = false;

  @override
  void dispose() {
    _unlock?.cancel();
    // Sem await: o dispose do leitor é assíncrono em algumas versões do plugin.
    _scanner.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    final now = DateTime.now();
    for (final barcode in capture.barcodes) {
      final code = barcode.rawValue;
      if (code == null || !Gtin.isValid(code)) continue;
      final last = _lastSeen[code];
      if (last != null && now.difference(last) < _rescanPause) return;
      _lastSeen[code] = now;
      unawaited(_onCode(code));
      return;
    }
  }

  Future<void> _onCode(String code) async {
    final product = await ref.read(productRepositoryProvider).findByBarcode(code);
    if (!mounted) return;
    if (product != null) {
      await _addToCart(product);
      return;
    }
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.cartUnknown(code)),
          action: SnackBarAction(label: l10n.cartRegister, onPressed: () => _register(code)),
        ),
      );
  }

  Future<void> _register(String code) async {
    final product = await _withScannerPaused(
      () => context.push<Product>(Routes.newProduct, extra: ProductFormArgs(barcode: code)),
    );
    if (product != null && mounted) await _addToCart(product);
  }

  /// Põe o produto no carrinho com o último preço dele no mercado da compra,
  /// e o marca na lista.
  Future<void> _addToCart(Product product) async {
    final trip = ref.read(activeTripProvider).value;
    if (trip == null) return;
    final cart = ref.read(cartRepositoryProvider);
    final list = ref.read(shoppingListRepositoryProvider);
    final marketId = trip.marketId;
    final expected = marketId == null
        ? null
        : latestPriceAt(await ref.read(priceRepositoryProvider).watchHistory(product.id).first, marketId);

    await cart.addProduct(trip.id, product.id, price: expected);
    await list.checkProduct(product.id);
    unawaited(HapticFeedback.mediumImpact());
    if (!mounted) return;
    setState(() => _locked = true);
    _unlock?.cancel();
    _unlock = Timer(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _locked = false);
    });
  }

  Future<void> _setTake(CartEntry entry, {required bool take}) async {
    await ref.read(cartRepositoryProvider).setTake(entry.item.id, take: take);
    final list = ref.read(shoppingListRepositoryProvider);
    await (take ? list.checkProduct(entry.product.id) : list.uncheckProduct(entry.product.id));
  }

  /// Digitar o preço de um item: ele é registrado no histórico (no mercado da
  /// compra) e vale para o carrinho.
  Future<void> _typePrice(ShoppingTrip trip, CartEntry entry) async {
    final l10n = AppLocalizations.of(context);
    final price = await _askPrice(entry.product.name, entry.item.price);
    if (price == null || !mounted) return;

    var marketId = trip.marketId;
    if (marketId == null) {
      marketId = (await _withScannerPaused(() => pickMarket(context)))?.id;
      if (marketId == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.cartNeedMarket)));
        return;
      }
      await ref.read(shoppingTripRepositoryProvider).setMarket(trip.id, marketId);
    }
    await ref.read(registerPriceObservationProvider).call(
      RegisterPriceInput(marketId: marketId, productId: entry.product.id, price: price, source: PriceSource.manual),
    );
    await ref.read(cartRepositoryProvider).setPrice(entry.item.id, price);
  }

  Future<Money?> _askPrice(String name, Money? current) {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: current?.formatDecimal() ?? '');
    return showDialog<Money>(
      context: context,
      builder: (context) {
        void submit() {
          final money = Money.tryParse(controller.text);
          if (money != null && money.isPositive) Navigator.of(context).pop(money);
        }

        return AlertDialog(
          title: Text(l10n.cartPriceTitle(name)),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(prefixText: r'R$ '),
            onSubmitted: (_) => submit(),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.cancel)),
            FilledButton(onPressed: submit, child: Text(l10n.save)),
          ],
        );
      },
    ).whenComplete(controller.dispose);
  }

  Future<void> _chooseMarket(ShoppingTrip trip) async {
    final market = await _withScannerPaused(() => pickMarket(context, selectedId: trip.marketId));
    if (market != null) await ref.read(shoppingTripRepositoryProvider).setMarket(trip.id, market.id);
  }

  /// O disparo abre a foto da etiqueta; o preço salvo lá entra no carrinho.
  Future<void> _photographTag() => _withScannerPaused(() => context.push<void>(Routes.capturePrice));

  Future<void> _finish(ShoppingTrip trip) async {
    setState(() => _finishing = true);
    await finishShopping(context, ref, trip.id);
    if (mounted) setState(() => _finishing = false);
  }

  /// Outra tela (a câmera da etiqueta, o cadastro) precisa da câmera, e o
  /// leitor não pode continuar lendo por baixo dela.
  Future<T?> _withScannerPaused<T>(Future<T?> Function() action) async {
    await _scanner.stop();
    try {
      return await action();
    } finally {
      if (mounted) await _scanner.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final trip = ref.watch(activeTripProvider).value;
    final cart = ref.watch(activeCartProvider).value ?? const <CartEntry>[];
    final summary = ref.watch(shoppingTripSummaryProvider);
    final marketName = ref.watch(activeTripMarketNameProvider);

    // A compra terminou (aqui ou na Lista): o carrinho fecha.
    ref.listen(activeTripProvider, (previous, next) {
      if (next case AsyncData(value: null) when previous?.value != null) {
        if (context.canPop()) context.pop();
      }
    });

    return Scaffold(
      backgroundColor: colors.camera,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _scanner, onDetect: _onDetect),
          Align(
            alignment: const Alignment(0, -0.45),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScanViewfinder(locked: _locked),
                if (cart.isEmpty) ...[
                  const SizedBox(height: BipaSpacing.s4),
                  Text(l10n.cartHint, style: BipaText.label.copyWith(color: colors.onCamera)),
                ],
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(BipaSpacing.s4, BipaSpacing.s4, BipaSpacing.s4, 0),
              child: Row(
                children: [
                  CameraGlassButton(icon: Icons.close_rounded, label: l10n.cartClose, onPressed: () => context.pop()),
                  const SizedBox(width: BipaSpacing.s2),
                  Expanded(
                    child: Center(
                      child: CameraGlassChip(
                        icon: Icons.storefront_outlined,
                        label: marketName ?? l10n.cartChooseMarket,
                        onTap: () {
                          if (trip != null) unawaited(_chooseMarket(trip));
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: BipaSpacing.s2),
                  CameraGlassButton(
                    icon: Icons.flashlight_on_outlined,
                    label: l10n.cartTorch,
                    onPressed: () => _scanner.toggleTorch(),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: ScanTray(
              title: l10n.cartTitle,
              countLabel: summary == null || summary.total == 0 ? null : l10n.cartFromList(summary.done, summary.total),
              totalLabel: l10n.cartTotal,
              totalValue: summary?.spent?.format(),
              items: [
                for (final entry in cart)
                  ScanTrayItem(
                    key: ValueKey(entry.item.id),
                    name: entry.item.quantity > 1
                        ? l10n.cartQuantity(entry.item.quantity, entry.product.name)
                        : entry.product.name,
                    price: entry.item.price?.format(),
                    take: entry.item.take,
                    takeLabel: l10n.cartTake(entry.product.name),
                    onTakeChanged: (take) => _setTake(entry, take: take),
                    priceTapLabel: l10n.cartTypePrice,
                    onPriceTap: () {
                      if (trip != null) unawaited(_typePrice(trip, entry));
                    },
                  ),
              ],
              footer: Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: IconButton.filledTonal(
                        tooltip: l10n.cartTypePrice,
                        onPressed: trip == null || cart.isEmpty ? null : () => _typePrice(trip, cart.first),
                        style: IconButton.styleFrom(
                          backgroundColor: colors.surfaceSunken,
                          foregroundColor: colors.ink,
                          fixedSize: const Size.square(48),
                        ),
                        icon: const Icon(Icons.keyboard_alt_outlined),
                      ),
                    ),
                  ),
                  ShutterButton(label: l10n.cartPhotoTag, onPressed: _photographTag),
                  Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: FilledButton(
                        onPressed: trip == null || _finishing ? null : () => _finish(trip),
                        style: FilledButton.styleFrom(
                          backgroundColor: colors.ink,
                          foregroundColor: colors.surface,
                          minimumSize: const Size(0, 48),
                        ),
                        child: Text(l10n.tripFinish),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
