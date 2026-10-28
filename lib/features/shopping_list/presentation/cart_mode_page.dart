import 'dart:async';

import 'package:bipa/core/camera/viewfinder_region.dart';
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
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/products/domain/product_package.dart';
import 'package:bipa/features/products/presentation/new_package_sheet.dart';
import 'package:bipa/features/products/presentation/products_providers.dart';
import 'package:bipa/features/shopping_list/domain/cart_item.dart';
import 'package:bipa/features/shopping_list/domain/live_scan.dart';
import 'package:bipa/features/shopping_list/domain/live_tag_router.dart';
import 'package:bipa/features/shopping_list/domain/shopping_trip.dart';
import 'package:bipa/features/shopping_list/presentation/finish_shopping.dart';
import 'package:bipa/features/shopping_list/presentation/live_scanner.dart';
import 'package:bipa/features/shopping_list/presentation/shopping_list_providers.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Modo carrinho (protótipos "Modo carrinho", "preço lido" e "preço
/// esperando"): a câmera fica aberta e lê, dentro da moldura, os códigos de
/// barras e as etiquetas (ADR 0012). Cada código entra na bandeja com o
/// último preço daquele mercado; o preço lido na etiqueta vai para o item
/// certo. O disparo continua fotografando a etiqueta, para as que a leitura
/// ao vivo deixa de lado.
class CartModePage extends ConsumerStatefulWidget {
  const CartModePage({super.key});

  @override
  ConsumerState<CartModePage> createState() => _CartModePageState();
}

/// O aviso sobre a câmera: o preço lido e o item que o recebeu, ou o pedido
/// de bipar o produto.
typedef _LiveNotice = ({Money price, String detail, bool waiting});

class _CartModePageState extends ConsumerState<CartModePage> with WidgetsBindingObserver {
  late final _live = LiveScanner(
    onEvents: _onEvents,
    viewfinder: _viewfinderOnScreen,
    analyzer: ref.read(liveFrameAnalyzerFactoryProvider)(),
    onError: _reportAny,
  );
  final _previewKey = GlobalKey();
  final _viewfinderKey = GlobalKey();
  static const _router = LiveTagRouter();

  /// O preço lido antes de bipar, esperando o próximo produto.
  PendingTagPrice? _pending;

  /// Itens com o preço firmado nesta compra (lido ao vivo, digitado ou
  /// fotografado), pela [CartItem.key]: uma etiqueta sem código lida depois
  /// não os sobrescreve.
  final _settledItems = <String>{};

  /// Preços de etiqueta já guardados no histórico, para não repetir a
  /// observação a cada vez que a mesma etiqueta volta à moldura.
  final _registeredTags = <String>{};

  _LiveNotice? _notice;
  String? _justReadKey;
  Timer? _noticeTimer;

  /// Os eventos da câmera são tratados um por vez, na ordem: um bipe termina
  /// de gravar antes de a etiqueta seguinte decidir para onde vai.
  Future<void> _eventQueue = Future.value();

  /// A moldura "trava" por um instante a cada leitura.
  var _locked = false;
  Timer? _unlock;
  var _finishing = false;
  var _cameraDenied = false;

  /// A câmera não abriu por outro motivo (ocupada por outro app, por
  /// exemplo): a tela diz isso e oferece tentar de novo, em vez de ficar preta.
  var _cameraFailed = false;

  /// A abertura da câmera pode pedir permissão, e o diálogo do Android deixa
  /// o app inativo por um instante: isso não é ir para o fundo.
  var _startingCamera = false;
  var _wentToBackground = false;

  /// Outra tela está usando a câmera: o leitor não volta sozinho ao app
  /// voltar do fundo.
  var _pausedForRoute = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _live.addListener(_onLiveChanged);
    // A prévia e o recorte supõem o celular em pé.
    unawaited(SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]));
    unawaited(_startCamera());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_pausedForRoute || _startingCamera) return;
    switch (state) {
      case AppLifecycleState.resumed:
        // Sem permissão, só tenta de novo depois de a pessoa sair do app (para
        // as configurações, por exemplo); senão, o pedido se repetiria.
        if (_cameraDenied && !_wentToBackground) return;
        _wentToBackground = false;
        unawaited(_startCamera());
      case AppLifecycleState.paused || AppLifecycleState.hidden:
        _wentToBackground = true;
        unawaited(_camera(_live.stop));
      case AppLifecycleState.inactive:
        unawaited(_camera(_live.stop));
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _unlock?.cancel();
    _noticeTimer?.cancel();
    _live
      ..removeListener(_onLiveChanged)
      ..dispose();
    unawaited(SystemChrome.setPreferredOrientations(const []));
    super.dispose();
  }

  void _onLiveChanged() {
    if (mounted) setState(() {});
  }

  /// Abre a câmera; sem permissão ou com falha, a tela explica no lugar da
  /// prévia.
  Future<void> _startCamera() async {
    _startingCamera = true;
    var denied = false;
    var failed = false;
    try {
      await _live.start();
    } on CameraException catch (error, stack) {
      denied = error.code.startsWith('CameraAccessDenied');
      failed = !denied;
      if (failed) _report(error, stack);
    } on Exception catch (error, stack) {
      failed = true;
      _report(error, stack);
    } finally {
      _startingCamera = false;
    }
    if (mounted && (denied != _cameraDenied || failed != _cameraFailed)) {
      setState(() {
        _cameraDenied = denied;
        _cameraFailed = failed;
      });
    }
  }

  /// A moldura na tela, relativa à prévia da câmera, para o recorte.
  ViewfinderOnScreen? _viewfinderOnScreen() {
    final preview = _previewKey.currentContext?.findRenderObject();
    final frame = _viewfinderKey.currentContext?.findRenderObject();
    if (preview is! RenderBox || frame is! RenderBox || !preview.hasSize || !frame.hasSize) return null;
    if (!preview.attached || !frame.attached) return null;
    final origin = frame.localToGlobal(Offset.zero) - preview.localToGlobal(Offset.zero);
    return (
      viewfinder: PixelRect(origin.dx, origin.dy, frame.size.width, frame.size.height),
      screenWidth: preview.size.width,
      screenHeight: preview.size.height,
    );
  }

  void _onEvents(List<LiveScanEvent> events) {
    for (final event in events) {
      _eventQueue = _eventQueue
          .then((_) async {
            if (!mounted) return;
            switch (event) {
              case ProductScanned(:final barcode):
                await _onCode(barcode);
              case TagPriceRead():
                await _onTagRead(event);
            }
          })
          // Uma falha não pode travar a fila dos próximos eventos.
          .then<void>((_) {}, onError: _reportAny);
    }
  }

  Future<void> _onCode(String code) async {
    final repository = ref.read(productRepositoryProvider);
    final Product? product;
    try {
      final package = await repository.findPackageByBarcode(code);
      product = package == null ? null : await repository.findById(package.productId);
      if (product != null && package != null && mounted) await _addToCart(product, package);
    } on Exception catch (error, stack) {
      _report(error, stack);
      return;
    }
    if (product != null || !mounted) return;
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
    // O aviso pode ser tocado depois de o carrinho fechar.
    if (!mounted) return;
    // A etiqueta lida há pouco sugere o produto, a marca e o tamanho, e mostra
    // o preço; a pessoa confere na folha (ADR 0013).
    final pending = _pending;
    final fromTag = pending != null && _router.fits(pending, barcode: code, now: DateTime.now()) ? pending.read : null;
    final created = await _withAnalysisPaused(
      () => showNewPackageSheet(context, ref, barcode: code, nameHint: fromTag?.nameHint, price: fromTag?.price),
    );
    if (created == null || !mounted) return;
    try {
      // O preço da etiqueta desse código esperou o cadastro, que leva tempo:
      // vale o que foi mostrado na folha.
      await _addToCart(created.product, created.package, registeredWith: fromTag);
    } on Exception catch (error, stack) {
      _report(error, stack);
    }
  }

  /// Põe a embalagem no carrinho e marca o produto na lista. O preço é o da
  /// etiqueta lida há pouco, se ela esperava por esta embalagem (ou o
  /// [registeredWith], a etiqueta que a folha de cadastro mostrou); senão, o
  /// último dela no mercado da compra.
  Future<void> _addToCart(Product product, ProductPackage package, {TagPriceRead? registeredWith}) async {
    final trip = ref.read(activeTripProvider).value;
    if (trip == null) return;
    final cart = ref.read(cartRepositoryProvider);
    final list = ref.read(shoppingListRepositoryProvider);
    final prices = ref.read(priceRepositoryProvider);
    final register = ref.read(registerPriceObservationProvider);

    final pending = _pending;
    final barcode = package.barcode;
    final fromTag =
        registeredWith ??
        (pending != null && barcode != null && _router.fits(pending, barcode: barcode, now: DateTime.now())
            ? pending.read
            : null);
    // Consumido na hora: outro bipe durante a gravação não leva o mesmo preço.
    if (fromTag != null && pending?.read == fromTag) _pending = null;
    final marketId = trip.marketId;
    final expected = fromTag != null || marketId == null
        ? null
        : latestPriceAt(await prices.watchHistory(product.id).first, marketId, packageId: package.id);

    await cart.addProduct(trip.id, product.id, packageId: package.id, price: fromTag?.price ?? expected);
    await list.checkProduct(product.id);
    unawaited(HapticFeedback.mediumImpact());
    final key = CartItem.keyOf(product.id, package.id);
    if (fromTag != null) {
      _settledItems.add(key);
      await _rememberTagPrice(register, trip, product.id, package.id, fromTag);
    }
    if (!mounted) return;
    _lockFrame();
    if (fromTag != null) {
      _showNotice((price: fromTag.price, detail: CartEntry.nameOf(product, package), waiting: false), key: key);
    }
  }

  /// Uma etiqueta lida ao vivo: o preço vai para o item certo ou espera o
  /// próximo produto (ADR 0012).
  Future<void> _onTagRead(TagPriceRead read) async {
    final trip = ref.read(activeTripProvider).value;
    if (trip == null) return;
    final products = ref.read(productRepositoryProvider);
    final cartRepository = ref.read(cartRepositoryProvider);
    final register = ref.read(registerPriceObservationProvider);
    final l10n = AppLocalizations.of(context);
    try {
      final barcode = read.barcode;
      final tagPackage = barcode == null ? null : await products.findPackageByBarcode(barcode);
      if (!mounted) return;
      final cart = ref.read(activeCartProvider).value ?? const <CartEntry>[];
      final settled = {
        for (final entry in cart)
          if (_settledItems.contains(entry.item.key)) entry.item.id,
      };
      final now = DateTime.now();
      switch (_router.route(read, cart: cart, now: now, tagPackageId: tagPackage?.id, settled: settled)) {
        case PriceCartItem(:final entry):
          await cartRepository.setPrice(entry.item.id, read.price);
          _settledItems.add(entry.item.key);
          await _rememberTagPrice(register, trip, entry.product.id, entry.item.packageId, read);
          unawaited(HapticFeedback.lightImpact());
          if (!mounted) return;
          _lockFrame();
          _showNotice((price: read.price, detail: entry.name, waiting: false), key: entry.item.key);
        case WaitForProduct(:final pending):
          _pending = pending;
          unawaited(HapticFeedback.selectionClick());
          _showNotice((price: read.price, detail: l10n.cartLiveWaiting, waiting: true), duration: _router.waitFor);
      }
    } on Exception catch (error, stack) {
      _report(error, stack);
    }
  }

  /// Guarda o preço da etiqueta no histórico do mercado da compra, com os
  /// outros preços dela (ADR 0011). Sem mercado escolhido, fica só no
  /// carrinho.
  Future<void> _rememberTagPrice(
    RegisterPriceObservation register,
    ShoppingTrip trip,
    String productId,
    String? packageId,
    TagPriceRead read,
  ) async {
    final marketId = trip.marketId;
    final key = '${CartItem.keyOf(productId, packageId)}:${read.price.cents}';
    if (marketId == null || _registeredTags.contains(key)) return;
    await register(
      RegisterPriceInput(
        marketId: marketId,
        productId: productId,
        packageId: packageId,
        price: read.price,
        source: PriceSource.priceTag,
        otherOffers: read.otherOffers,
      ),
    );
    _registeredTags.add(key);
  }

  void _lockFrame() {
    setState(() => _locked = true);
    _unlock?.cancel();
    _unlock = Timer(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _locked = false);
    });
  }

  /// [key] é a [CartItem.key] do item que recebeu o preço, para o anel.
  void _showNotice(_LiveNotice notice, {String? key, Duration duration = const Duration(milliseconds: 2500)}) {
    if (!mounted) return;
    setState(() {
      _notice = notice;
      _justReadKey = key;
    });
    _noticeTimer?.cancel();
    _noticeTimer = Timer(duration, () {
      if (!mounted) return;
      setState(() {
        _notice = null;
        _justReadKey = null;
      });
    });
  }

  Future<void> _setTake(CartEntry entry, {required bool take}) async {
    final cart = ref.read(cartRepositoryProvider);
    final list = ref.read(shoppingListRepositoryProvider);
    // Outra embalagem do mesmo produto que vai no carrinho mantém o produto
    // marcado na lista.
    final otherTaken = (ref.read(activeCartProvider).value ?? const <CartEntry>[]).any(
      (other) => other.item.id != entry.item.id && other.product.id == entry.product.id && other.item.take,
    );
    try {
      await cart.setTake(entry.item.id, take: take);
      if (take) {
        await list.checkProduct(entry.product.id);
      } else if (!otherTaken) {
        await list.uncheckProduct(entry.product.id);
      }
    } on Exception catch (error, stack) {
      _report(error, stack);
    }
  }

  /// Digitar o preço de um item: ele é registrado no histórico (no mercado da
  /// compra) e vale para o carrinho.
  Future<void> _typePrice(ShoppingTrip trip, CartEntry entry) async {
    // Lidos antes dos awaits: o carrinho pode fechar no meio do caminho.
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final trips = ref.read(shoppingTripRepositoryProvider);
    final register = ref.read(registerPriceObservationProvider);
    final cart = ref.read(cartRepositoryProvider);

    final price = await _withAnalysisPaused(
      () => showDialog<Money>(
        context: context,
        builder: (_) => _PriceDialog(title: l10n.cartPriceTitle(entry.name), initial: entry.item.price),
      ),
    );
    if (price == null || !mounted) return;

    var marketId = trip.marketId;
    if (marketId == null) {
      marketId = (await _withScannerPaused(() => pickMarket(context)))?.id;
      if (marketId == null) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.cartNeedMarket)));
        return;
      }
    }
    try {
      if (trip.marketId == null) await trips.setMarket(trip.id, marketId);
      await register(
        RegisterPriceInput(
          marketId: marketId,
          productId: entry.product.id,
          packageId: entry.item.packageId,
          price: price,
          source: PriceSource.manual,
        ),
      );
      await cart.setPrice(entry.item.id, price);
      _settledItems.add(entry.item.key);
    } on Exception {
      messenger.showSnackBar(SnackBar(content: Text(l10n.cartPriceFailed)));
    }
  }

  Future<void> _chooseMarket(ShoppingTrip trip) async {
    final market = await _withScannerPaused(() => pickMarket(context, selectedId: trip.marketId));
    if (market != null) await ref.read(shoppingTripRepositoryProvider).setMarket(trip.id, market.id);
  }

  /// O disparo abre a foto da etiqueta; o preço salvo lá entra no carrinho
  /// e fica firmado: a etiqueta lida ao vivo na volta não o sobrescreve.
  Future<void> _photographTag() async {
    final priced = await _withScannerPaused(() => context.push<Set<String>>(Routes.capturePriceFromCart));
    if (priced != null) _settledItems.addAll(priced);
  }

  Future<void> _finish(ShoppingTrip trip) async {
    setState(() => _finishing = true);
    try {
      await _withAnalysisPaused(() => finishShopping(context, ref, trip.id));
    } finally {
      if (mounted) setState(() => _finishing = false);
    }
  }

  /// Um diálogo por cima: a prévia continua, mas nada é lido por baixo dele.
  Future<T> _withAnalysisPaused<T>(Future<T> Function() action) async {
    _live.analysisPaused = true;
    try {
      return await action();
    } finally {
      _live.analysisPaused = false;
    }
  }

  /// Outra tela (a câmera da etiqueta, o cadastro) precisa da câmera, e o
  /// leitor não pode continuar lendo por baixo dela.
  Future<T?> _withScannerPaused<T>(Future<T?> Function() action) async {
    _pausedForRoute = true;
    await _camera(_live.stop);
    try {
      return await action();
    } finally {
      _pausedForRoute = false;
      if (mounted) await _startCamera();
    }
  }

  /// A lanterna falha se a câmera não abriu (sem permissão, por exemplo).
  Future<void> _toggleTorch() => _camera(_live.toggleTorch);

  /// Comandos da câmera que podem falhar sem derrubar a tela: o erro vai para
  /// o relatório e o leitor segue como está.
  Future<void> _camera(Future<void> Function() command) async {
    try {
      await command();
    } on Exception catch (error, stack) {
      _report(error, stack);
    }
  }

  void _report(Exception error, StackTrace stack) => _reportAny(error, stack);

  void _reportAny(Object error, StackTrace stack) =>
      FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack, library: 'shopping_list'));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final trip = ref.watch(activeTripProvider).value;
    final cart = ref.watch(activeCartProvider).value ?? const <CartEntry>[];
    final summary = ref.watch(shoppingTripSummaryProvider);
    final marketName = ref.watch(activeTripMarketNameProvider);
    final notice = _notice;
    final controller = _live.controller;
    final previewSize = controller?.value.previewSize;

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
          // A prévia preenche a tela (cover); o recorte de cada quadro conta
          // com isso (viewfinderInImage).
          SizedBox.expand(
            key: _previewKey,
            child: controller == null || previewSize == null || !controller.value.isInitialized
                ? null
                : ClipRect(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: previewSize.height,
                        height: previewSize.width,
                        child: CameraPreview(controller),
                      ),
                    ),
                  ),
          ),
          if (_cameraFailed)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: BipaSpacing.s6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.cartCameraFailed,
                      textAlign: TextAlign.center,
                      style: BipaText.label.copyWith(color: colors.onCamera),
                    ),
                    const SizedBox(height: BipaSpacing.s4),
                    FilledButton.tonal(onPressed: _startCamera, child: Text(l10n.cartCameraRetry)),
                  ],
                ),
              ),
            )
          else
            Align(
              alignment: const Alignment(0, -0.45),
              // O tamanho fixo é o da moldura aberta: o recorte não muda quando
              // ela trava. O aviso fica logo abaixo, sem empurrar a moldura.
              child: SizedBox(
                key: _viewfinderKey,
                width: 260,
                height: 150,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Center(child: ScanViewfinder(locked: _locked)),
                    Positioned(
                      top: 150 + BipaSpacing.s4,
                      left: -BipaSpacing.s8 * 2,
                      right: -BipaSpacing.s8 * 2,
                      child: Center(
                        child: switch ((notice, _cameraDenied)) {
                          ((:final price, :final detail, :final waiting)?, _) => LiveReadChip(
                            icon: waiting ? Icons.qr_code_scanner_rounded : Icons.sell_outlined,
                            price: price.format(),
                            detail: detail,
                          ),
                          (null, true) => Text(
                            l10n.cartCameraDenied,
                            textAlign: TextAlign.center,
                            style: BipaText.label.copyWith(color: colors.onCamera),
                          ),
                          (null, false) when cart.isEmpty => Text(
                            l10n.cartHint,
                            textAlign: TextAlign.center,
                            style: BipaText.label.copyWith(color: colors.onCamera),
                          ),
                          _ => const SizedBox.shrink(),
                        },
                      ),
                    ),
                  ],
                ),
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
                    icon: _live.torchOn ? Icons.flashlight_off_outlined : Icons.flashlight_on_outlined,
                    label: l10n.cartTorch,
                    onPressed: _toggleTorch,
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
                        ? l10n.cartQuantity(entry.item.quantity, entry.name)
                        : entry.name,
                    price: entry.item.price?.format(),
                    justRead: entry.item.key == _justReadKey,
                    take: entry.item.take,
                    takeLabel: l10n.cartTake(entry.name),
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

/// O diálogo de digitar o preço, dono do próprio campo: o controller só é
/// descartado quando o diálogo sai da árvore, depois da animação.
class _PriceDialog extends StatefulWidget {
  const _PriceDialog({required this.title, this.initial});

  final String title;
  final Money? initial;

  @override
  State<_PriceDialog> createState() => _PriceDialogState();
}

class _PriceDialogState extends State<_PriceDialog> {
  late final _controller = TextEditingController(text: widget.initial?.formatDecimal() ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final money = Money.tryParse(_controller.text);
    if (money != null && money.isPositive) Navigator.of(context).pop(money);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(prefixText: r'R$ '),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.cancel)),
        FilledButton(onPressed: _submit, child: Text(l10n.save)),
      ],
    );
  }
}
