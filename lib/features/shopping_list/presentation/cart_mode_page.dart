import 'dart:async';

import 'package:bipa/core/design_system/bipa_metrics.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/design_system/components/scan_tray.dart';
import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/core/widgets/price_dialog.dart';
import 'package:bipa/core/widgets/quantity_dialog.dart';
import 'package:bipa/features/markets/presentation/market_picker_sheet.dart';
import 'package:bipa/features/prices/domain/price_comparison.dart';
import 'package:bipa/features/prices/domain/price_source.dart';
import 'package:bipa/features/prices/presentation/prices_providers.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/products/domain/product_package.dart';
import 'package:bipa/features/products/domain/scale_label.dart';
import 'package:bipa/features/products/presentation/new_package_sheet.dart';
import 'package:bipa/features/products/presentation/product_picker_sheet.dart';
import 'package:bipa/features/products/presentation/products_providers.dart';
import 'package:bipa/features/shopping_list/domain/cart_item.dart';
import 'package:bipa/features/shopping_list/domain/live_scan.dart';
import 'package:bipa/features/shopping_list/domain/live_tag_router.dart';
import 'package:bipa/features/shopping_list/domain/record_trip_price.dart';
import 'package:bipa/features/shopping_list/domain/shopping_trip.dart';
import 'package:bipa/features/shopping_list/presentation/change_trip_market.dart';
import 'package:bipa/features/shopping_list/presentation/finish_shopping.dart';
import 'package:bipa/features/shopping_list/presentation/live_camera.dart';
import 'package:bipa/features/shopping_list/presentation/photograph_tag.dart';
import 'package:bipa/features/shopping_list/presentation/shopping_list_providers.dart';
import 'package:bipa/features/shopping_list/presentation/trip_summary_label.dart';
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
typedef _LiveNotice = ({String? price, String detail, bool waiting});

class _CartModePageState extends ConsumerState<CartModePage> {
  final _cameraKey = GlobalKey<LiveCameraState>();
  static const _router = LiveTagRouter();

  /// O preço lido antes de bipar, esperando o próximo produto.
  PendingTagPrice? _pending;

  /// Itens com o preço firmado nesta compra (lido ao vivo, digitado ou
  /// fotografado), pela [CartItem.key]: uma etiqueta sem código lida depois
  /// não os sobrescreve. Os preços lidos e digitados também ficam guardados
  /// com a compra (ADR 0020), e valem como firmados depois de reabrir o
  /// carrinho.
  final _settledItems = <String>{};

  _LiveNotice? _notice;

  /// O que tocar no aviso faz, enquanto ele está na tela: escolher o produto
  /// do granel (ADR 0018) ou do preço que espera o produto (D5).
  VoidCallback? _noticeTap;
  String? _justReadKey;
  Timer? _noticeTimer;

  var _finishing = false;

  /// A bandeja aberta mostra mais itens (a alça alterna).
  var _trayExpanded = false;

  @override
  void dispose() {
    _noticeTimer?.cancel();
    super.dispose();
  }

  /// Cada leitura da câmera, uma de cada vez: um bipe termina de gravar antes
  /// de a etiqueta seguinte decidir para onde vai.
  Future<void> _onEvent(LiveScanEvent event) async {
    switch (event) {
      case ProductScanned(:final barcode):
        await _onCode(barcode);
      case TagPriceRead():
        await _onTagRead(event);
    }
  }

  Future<void> _onCode(String code) async {
    // A etiqueta da balança não é código de produto (ADR 0018).
    if (ScaleLabel.tryParse(code) case final label?) return _onScaleLabel(label);
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
    // Código novo: a folha "Embalagem nova" abre direto (protótipo), com a
    // leitura pausada por baixo. Um aviso com prazo não dá tempo com o
    // produto na mão.
    await _register(code);
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

  /// Tocou no aviso do granel: escolhe o produto (já buscado pelo nome lido)
  /// e guarda o preço por kg no histórico do mercado. Quanto custa sai da
  /// etiqueta da balança ou do preço digitado (ADR 0018).
  Future<void> _chooseGranel(TagPriceRead read) async {
    final trip = ref.read(activeTripProvider).value;
    if (trip == null) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final recordPrice = ref.read(recordTripPriceProvider);
    final createProduct = ref.read(createProductByWeightProvider);
    _clearNotice();
    final choice = await _withAnalysisPaused(
      () => pickProduct(
        context,
        initialQuery: read.nameHint ?? '',
        title: l10n.cartGranelTitle(l10n.pricePerKilo(read.price.format())),
      ),
    );
    if (choice == null || !mounted) return;
    try {
      final product = switch (choice) {
        ExistingProduct(product: final chosen) => chosen,
        NewProduct(:final name) => await createProduct(name),
      };
      // Sem mercado, o preço espera com a compra (ADR 0020). A mesma etiqueta,
      // tocada de novo, não repete o preço no histórico.
      await _recordTag(recordPrice, trip, product.id, null, read);
      if (!mounted) return;
      _lockFrame();
      _showNotice((
        price: l10n.pricePerKilo(read.price.format()),
        detail: l10n.cameraPriceSaved(product.name),
        waiting: false,
      ));
    } on Exception {
      messenger.showSnackBar(SnackBar(content: Text(l10n.cartPriceFailed)));
    }
  }

  /// Uma etiqueta da balança (ADR 0018): o produto do código é perguntado
  /// uma vez por mercado e lembrado; o valor da pesagem vai para o carrinho.
  Future<void> _onScaleLabel(ScaleLabel label) async {
    final trip = ref.read(activeTripProvider).value;
    if (trip == null) return;
    final scale = ref.read(scaleItemsProvider);
    final list = ref.read(shoppingListRepositoryProvider);
    final l10n = AppLocalizations.of(context);
    try {
      var product = await scale.productFor(trip.marketId, label);
      if (product == null) {
        if (!mounted) return;
        final choice = await _withAnalysisPaused(
          () => pickProduct(context, title: l10n.cartScaleTitle(label.total.format())),
        );
        product = switch (choice) {
          ExistingProduct(product: final chosen) => await scale.remember(trip.marketId, label, product: chosen),
          NewProduct(:final name) => await scale.remember(trip.marketId, label, newName: name),
          null => null,
        };
      }
      if (product == null) return;
      await scale.addToCart(trip.id, product, label);
      await list.checkProduct(product.id);
      unawaited(HapticFeedback.mediumImpact());
      unawaited(SystemSound.play(SystemSoundType.click));
      if (!mounted) return;
      _lockFrame();
      final key = CartItem.keyOf(product.id, null);
      // A pesagem é o preço firmado: uma etiqueta lida depois não o troca.
      _settledItems.add(key);
      _showNotice((price: label.total.format(), detail: product.name, waiting: false), key: key);
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
    final recordPrice = ref.read(recordTripPriceProvider);

    final pending = _pending;
    final barcode = package.barcode;
    final fromTag =
        registeredWith ??
        (pending != null &&
                barcode != null &&
                _router.fits(pending, barcode: barcode, now: DateTime.now(), productName: product.name)
            ? pending.read
            : null);
    // Consumido na hora: outro bipe durante a gravação não leva o mesmo preço.
    if (fromTag != null && pending?.read == fromTag) _pending = null;
    final marketId = trip.marketId;
    final expected = fromTag != null || marketId == null
        ? null
        : latestPriceAt(await prices.watchHistory(product.id).first, marketId, packageId: package.id);

    await cart.addProduct(
      trip.id,
      product.id,
      packageId: package.id,
      price: fromTag?.price ?? expected,
      // O preço do histórico é uma estimativa até a etiqueta ser lida.
      estimated: fromTag == null,
    );
    await list.checkProduct(product.id);
    unawaited(HapticFeedback.mediumImpact());
    // O bipe: o som de clique do sistema, que segue a configuração de sons de
    // toque do aparelho (desligado lá, desligado aqui).
    unawaited(SystemSound.play(SystemSoundType.click));
    final key = CartItem.keyOf(product.id, package.id);
    if (fromTag != null) {
      _settledItems.add(key);
      await _recordTag(recordPrice, trip, product.id, package.id, fromTag);
    }
    if (!mounted) return;
    _lockFrame();
    if (fromTag != null) {
      _showNotice((
        price: fromTag.price.format(),
        detail: CartEntry.nameOf(product, package),
        waiting: false,
      ), key: key);
    }
  }

  /// Uma etiqueta lida ao vivo: o preço vai para o item certo ou espera o
  /// próximo produto (ADR 0012).
  Future<void> _onTagRead(TagPriceRead read) async {
    final trip = ref.read(activeTripProvider).value;
    if (trip == null) return;
    // A etiqueta da balança já entra pelo código dela, com o mesmo valor
    // (ADR 0018); lida também como etiqueta, somaria duas vezes.
    if (read.barcode case final code? when ScaleLabel.isScaleCode(code)) return;
    // Granel sem código: não vem produto bipado para esperar. O aviso vira
    // botão para escolher o produto (protótipo "granel sem código").
    if (read.perKilo && read.barcode == null) {
      final l10n = AppLocalizations.of(context);
      unawaited(HapticFeedback.selectionClick());
      _showNotice(
        (
          price: l10n.pricePerKilo(read.price.format()),
          detail: switch (read.nameHint) {
            final name? => l10n.cartGranelGuess(name),
            null => l10n.cartGranelChoose,
          },
          waiting: false,
        ),
        onTap: () => _chooseGranel(read),
        duration: _router.waitFor,
      );
      return;
    }
    final products = ref.read(productRepositoryProvider);
    final cartRepository = ref.read(cartRepositoryProvider);
    final recordPrice = ref.read(recordTripPriceProvider);
    final tripPrices = ref.read(tripPriceRepositoryProvider);
    final l10n = AppLocalizations.of(context);
    try {
      final barcode = read.barcode;
      final tagPackage = barcode == null ? null : await products.findPackageByBarcode(barcode);
      if (!mounted) return;
      final cart = ref.read(activeCartProvider).value ?? const <CartEntry>[];
      // Firmado nesta tela ou com preço guardado na compra (ADR 0020), que
      // vale também depois de reabrir o carrinho.
      final withPrice = {for (final price in await tripPrices.ofTrip(trip.id)) price.itemKey};
      if (!mounted) return;
      final settled = {
        for (final entry in cart)
          if (_settledItems.contains(entry.item.key) || withPrice.contains(entry.item.key)) entry.item.id,
      };
      final now = DateTime.now();
      switch (_router.route(read, cart: cart, now: now, tagPackageId: tagPackage?.id, settled: settled)) {
        case PriceCartItem(:final entry):
          await cartRepository.setPrice(entry.item.id, read.price);
          _settledItems.add(entry.item.key);
          await _recordTag(recordPrice, trip, entry.product.id, entry.item.packageId, read);
          unawaited(HapticFeedback.lightImpact());
          if (!mounted) return;
          _lockFrame();
          _showNotice((price: read.price.format(), detail: entry.name, waiting: false), key: entry.item.key);
        case WaitForProduct(:final pending):
          _pending = pending;
          unawaited(HapticFeedback.selectionClick());
          // Código fora de alcance: tocar no aviso escolhe o produto pelo
          // nome lido (D5).
          _showNotice(
            (price: read.price.format(), detail: l10n.cartLiveWaiting, waiting: true),
            onTap: () => _chooseProductFor(read),
            duration: _router.waitFor,
          );
      }
    } on Exception catch (error, stack) {
      _report(error, stack);
    }
  }

  /// Guarda o preço da etiqueta com a compra (ADR 0020), com os outros
  /// preços dela (ADR 0011): no histórico do mercado, ou à espera dele. A
  /// mesma etiqueta lida de novo não repete o preço.
  static Future<void> _recordTag(
    RecordTripPrice recordPrice,
    ShoppingTrip trip,
    String productId,
    String? packageId,
    TagPriceRead read,
  ) async {
    await recordPrice(
      tripId: trip.id,
      productId: productId,
      packageId: packageId,
      price: read.price,
      source: PriceSource.priceTag,
      otherOffers: read.otherOffers,
      perKilo: read.perKilo,
    );
  }

  void _lockFrame() => _cameraKey.currentState?.lock();

  /// [key] é a [CartItem.key] do item que recebeu o preço, para o anel;
  /// [onTap] faz do aviso um botão.
  void _showNotice(
    _LiveNotice notice, {
    String? key,
    VoidCallback? onTap,
    Duration duration = const Duration(milliseconds: 2500),
  }) {
    if (!mounted) return;
    setState(() {
      _notice = notice;
      _justReadKey = key;
      _noticeTap = onTap;
    });
    _noticeTimer?.cancel();
    _noticeTimer = Timer(duration, _clearNotice);
  }

  void _clearNotice() {
    _noticeTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _notice = null;
      _justReadKey = null;
      _noticeTap = null;
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
    final recordPrice = ref.read(recordTripPriceProvider);
    final cart = ref.read(cartRepositoryProvider);

    final price = await _withAnalysisPaused(
      () => showPriceDialog(context, title: l10n.cartPriceTitle(entry.name), initial: entry.item.price),
    );
    if (price == null || !mounted) return;

    try {
      // Corrige o que foi guardado antes para o item no mesmo mercado (a
      // etiqueta lida ou o preço digitado da outra vez), em vez de somar mais
      // um preço. Sem mercado, espera com a compra (ADR 0020).
      await recordPrice(
        tripId: trip.id,
        productId: entry.product.id,
        packageId: entry.item.packageId,
        price: price,
        source: PriceSource.manual,
      );
      await cart.setPrice(entry.item.id, price);
      _settledItems.add(entry.item.key);
    } on Exception {
      messenger.showSnackBar(SnackBar(content: Text(l10n.cartPriceFailed)));
    }
  }

  /// Tocar no nome: quantas unidades vão.
  Future<void> _setQuantity(CartEntry entry) async {
    final cart = ref.read(cartRepositoryProvider);
    final chosen = await _withAnalysisPaused(
      () => showQuantityDialog(context, title: entry.name, initial: entry.item.quantity),
    );
    if (chosen == null || chosen == entry.item.quantity) return;
    try {
      await cart.setQuantity(entry.item.id, chosen);
    } on Exception catch (error, stack) {
      _report(error, stack);
    }
  }

  /// O chip do mercado: os preços que esperavam vão para o escolhido, e os
  /// já gravados em outro vão junto se a pessoa quiser (ADR 0020).
  Future<void> _chooseMarket(ShoppingTrip trip) async {
    final market = await _withScannerPaused(() => pickMarket(context, selectedId: trip.marketId));
    if (market == null || !mounted) return;
    await _withAnalysisPaused(() => changeTripMarket(context, ref, trip, market));
  }

  /// O disparo: fotografa pela própria câmera ao vivo, e o preço segue como
  /// a leitura ao vivo.
  Future<void> _shoot() async {
    final camera = _cameraKey.currentState;
    if (camera == null) return;
    final l10n = AppLocalizations.of(context);
    final reader = ref.read(priceTagReaderProvider);
    unawaited(HapticFeedback.mediumImpact());
    final TagPriceRead? read;
    try {
      read = await camera.withAnalysisPaused(() => photographTag(camera, reader));
    } on Exception catch (error, stack) {
      _report(error, stack);
      _showNotice((price: null, detail: l10n.cameraPhotoNoPrice, waiting: false));
      return;
    }
    if (!mounted) return;
    if (read == null) {
      _showNotice((price: null, detail: l10n.cameraPhotoNoPrice, waiting: false));
      return;
    }
    await _onTagRead(read);
  }

  /// Tocou no aviso do preço que esperava o produto: escolhe pelo nome lido,
  /// e o produto entra no carrinho com esse preço.
  Future<void> _chooseProductFor(TagPriceRead read) async {
    final trip = ref.read(activeTripProvider).value;
    if (trip == null) return;
    final l10n = AppLocalizations.of(context);
    final cart = ref.read(cartRepositoryProvider);
    final list = ref.read(shoppingListRepositoryProvider);
    final recordPrice = ref.read(recordTripPriceProvider);
    _clearNotice();
    final choice = await _withAnalysisPaused(
      () => pickProduct(context, allowCreate: false, initialQuery: read.nameHint ?? '', title: l10n.cameraWhichProduct),
    );
    if (choice is! ExistingProduct || !mounted) return;
    // A espera foi usada: não vai para o próximo bipe.
    if (_pending?.read == read) _pending = null;
    final product = choice.product;
    try {
      await cart.addProduct(trip.id, product.id, price: read.price);
      await list.checkProduct(product.id);
      _settledItems.add(CartItem.keyOf(product.id, null));
      await _recordTag(recordPrice, trip, product.id, null, read);
    } on Exception catch (error, stack) {
      _report(error, stack);
      return;
    }
    if (!mounted) return;
    final key = CartItem.keyOf(product.id, null);
    _showNotice((price: read.price.format(), detail: product.name, waiting: false), key: key);
  }

  /// "Terminei": a escolha do mercado para os preços que esperavam vem no
  /// [finishShopping], comum ao carrinho, à Lista e à notificação.
  Future<void> _finish(ShoppingTrip trip) async {
    setState(() => _finishing = true);
    try {
      await _withAnalysisPaused(() => finishShopping(context, ref, trip.id));
    } finally {
      if (mounted) setState(() => _finishing = false);
    }
  }

  /// Um diálogo por cima: a prévia continua, mas nada é lido por baixo dele.
  Future<T> _withAnalysisPaused<T>(Future<T> Function() action) =>
      _cameraKey.currentState?.withAnalysisPaused(action) ?? action();

  /// Outra tela (a câmera da etiqueta, o cadastro) precisa da câmera.
  Future<T?> _withScannerPaused<T>(Future<T?> Function() action) =>
      _cameraKey.currentState?.withScannerPaused(action) ?? action();

  void _report(Object error, StackTrace stack) =>
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
    // Observado enquanto o carrinho está aberto: o leitor do disparo carrega
    // os modelos do ML Kit uma vez e os solta ao sair.
    ref.watch(priceTagReaderProvider);

    // A compra terminou (aqui ou na Lista): o carrinho fecha.
    ref.listen(activeTripProvider, (previous, next) {
      if (next case AsyncData(value: null) when previous?.value != null) {
        if (context.canPop()) context.pop();
      }
    });

    return Scaffold(
      backgroundColor: colors.camera,
      body: LiveCamera(
        key: _cameraKey,
        onEvent: _onEvent,
        notice: switch (notice) {
          (:final price, :final detail, :final waiting)? => LiveReadChip(
            // O preço que espera mostra o tempo que falta.
            key: ValueKey((price, waiting)),
            icon: waiting ? Icons.qr_code_scanner_rounded : Icons.sell_outlined,
            price: price,
            detail: detail,
            countdown: waiting ? _router.waitFor : null,
            // O granel sem código, ou o preço que espera o produto: o aviso
            // escolhe o produto.
            onTap: _noticeTap,
          ),
          null => null,
        },
        hint: cart.isEmpty ? l10n.cartHint : null,
        topBar: (camera) => Row(
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
              icon: camera.torchOn ? Icons.flashlight_off_outlined : Icons.flashlight_on_outlined,
              label: l10n.cartTorch,
              onPressed: camera.toggleTorch,
            ),
          ],
        ),
        bottom: ScanTray(
          title: l10n.cartTitle,
          countLabel: summary == null || summary.total == 0 ? null : l10n.cartFromList(summary.done, summary.total),
          totalLabel: l10n.cartTotal,
          // Com preço do histórico no meio, o total é uma estimativa ("≈").
          totalValue: summary?.spentLabel(l10n),
          totalNote: (summary?.unpriced ?? 0) > 0 ? l10n.marketsMissingPrices(summary!.unpriced) : null,
          maxListHeight: _trayExpanded ? MediaQuery.sizeOf(context).height * 0.55 : 196,
          handleLabel: _trayExpanded ? l10n.cartTrayLess : l10n.cartTrayMore,
          onHandleTap: () => setState(() => _trayExpanded = !_trayExpanded),
          expanded: _trayExpanded,
          items: [
            for (final entry in cart)
              ScanTrayItem(
                key: ValueKey(entry.item.id),
                name: entry.item.quantity > 1 ? l10n.cartQuantity(entry.item.quantity, entry.name) : entry.name,
                // O estimado se distingue só pela etiqueta vazada: um sinal só.
                price: entry.item.price?.format(),
                priceEstimated: entry.item.priceEstimated,
                priceSemanticsLabel: switch (entry.item.price) {
                  final price? when entry.item.priceEstimated => l10n.cartPriceEstimated(price.format()),
                  _ => null,
                },
                onNameTap: () => _setQuantity(entry),
                nameTapLabel: l10n.cartQuantityOf(entry.name),
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
                    // Digita o preço do último bipado: o rótulo diz qual.
                    tooltip: cart.isEmpty ? l10n.cartTypePrice : l10n.cartTypePriceOf(cart.first.name),
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
              ShutterButton(label: l10n.cartPhotoTag, onPressed: _shoot),
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
    );
  }
}
