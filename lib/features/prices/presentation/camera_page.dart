import 'dart:async';

import 'package:bipa/core/design_system/bipa_metrics.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/design_system/components/camera_mode_switch.dart';
import 'package:bipa/core/design_system/components/scan_tray.dart';
import 'package:bipa/core/formatting/formatters.dart';
import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/core/location/location_service.dart';
import 'package:bipa/core/navigation/routes.dart';
import 'package:bipa/features/markets/domain/market.dart';
import 'package:bipa/features/markets/presentation/market_picker_sheet.dart';
import 'package:bipa/features/markets/presentation/markets_providers.dart';
import 'package:bipa/features/prices/domain/price_source.dart';
import 'package:bipa/features/prices/presentation/confirm_price_sheet.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/products/domain/product_package.dart';
import 'package:bipa/features/products/domain/scale_label.dart';
import 'package:bipa/features/products/presentation/new_package_sheet.dart';
import 'package:bipa/features/products/presentation/product_picker_sheet.dart';
import 'package:bipa/features/products/presentation/products_providers.dart';
import 'package:bipa/features/shopping_list/domain/cart_item.dart';
import 'package:bipa/features/shopping_list/domain/live_scan.dart';
import 'package:bipa/features/shopping_list/presentation/live_camera.dart';
import 'package:bipa/features/shopping_list/presentation/start_shopping.dart';
import 'package:bipa/features/stock/domain/stock_item.dart';
import 'package:bipa/features/stock/domain/stock_movement_reason.dart';
import 'package:bipa/features/stock/presentation/stock_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// O que a câmera faz com cada leitura.
enum CameraMode {
  /// A etiqueta: o preço lido vai para a folha de conferir e salvar.
  price('etiqueta'),

  /// O código: abre o produto.
  find('codigo'),

  /// "Comprei": cada código soma uma embalagem em casa (o Início vazio).
  bought('comprei'),

  /// "Dar baixa em casa": cada código tira uma embalagem.
  used('usei');

  const CameraMode(this.query);

  /// O valor na rota (`/camera?modo=usei`).
  final String query;

  static CameraMode fromQuery(String? value) => values.where((mode) => mode.query == value).firstOrNull ?? price;
}

/// O que a câmera mostra abaixo da moldura depois de uma leitura.
typedef _Notice = ({IconData icon, String? value, String detail, bool waiting});

/// A câmera do botão de bipar (protótipo "Captura"): abre direto, lendo ao
/// vivo como o modo carrinho (ADR 0012). Em "Etiqueta", o preço lido abre a
/// folha de conferir e salvar; em "Código", o produto. Pelo menu do bipar e
/// pelo Início vazio, os mesmos bipes dão baixa ou somam em casa, um atrás
/// do outro. O mercado fica no chip do topo e só é pedido no "Salvar".
class CameraPage extends ConsumerStatefulWidget {
  const CameraPage({this.mode = CameraMode.price, super.key});

  final CameraMode mode;

  @override
  ConsumerState<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends ConsumerState<CameraPage> {
  final _cameraKey = GlobalKey<LiveCameraState>();
  late var _mode = widget.mode;
  Market? _market;

  /// Quanto um preço sem código espera o produto, e um produto espera a
  /// etiqueta: o mesmo prazo do modo carrinho.
  static const _waitFor = Duration(seconds: 20);

  /// A etiqueta sem código lida há pouco, esperando o produto ser bipado.
  ({TagPriceRead read, DateTime at})? _pendingTag;

  /// O produto bipado há pouco, esperando a etiqueta.
  ({Product product, ProductPackage package, DateTime at})? _pendingProduct;

  _Notice? _notice;
  Timer? _noticeTimer;

  @override
  void initState() {
    super.initState();
    unawaited(_detectMarket());
  }

  @override
  void dispose() {
    _noticeTimer?.cancel();
    super.dispose();
  }

  /// O mercado em que a pessoa está, se a localização já foi permitida:
  /// abrir a câmera não pede nada.
  Future<void> _detectMarket() async {
    final location = ref.read(locationServiceProvider);
    final markets = ref.read(marketRepositoryProvider);
    final finder = ref.read(nearestMarketFinderProvider);
    try {
      final position = await location.currentLocation(request: false);
      if (position is! LocationFound) return;
      final market = finder.marketAt(position.point, await markets.all());
      if (mounted && market != null && _market == null) setState(() => _market = market);
    } on Exception catch (error, stack) {
      // Sem o mercado, o chip pede para escolher: não há o que avisar.
      FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack, library: 'camera'));
    }
  }

  Future<void> _chooseMarket() async {
    final market = await _withScannerPaused(() => pickMarket(context, selectedId: _market?.id));
    if (market != null && mounted) setState(() => _market = market);
  }

  Future<T> _withAnalysisPaused<T>(Future<T> Function() action) =>
      _cameraKey.currentState?.withAnalysisPaused(action) ?? action();

  Future<T?> _withScannerPaused<T>(Future<T?> Function() action) =>
      _cameraKey.currentState?.withScannerPaused(action) ?? action();

  void _showNotice(
    _Notice notice, {
    TagPriceRead? granel,
    Duration duration = const Duration(milliseconds: 2500),
  }) {
    if (!mounted) return;
    setState(() {
      _notice = notice;
      _granel = granel;
    });
    _noticeTimer?.cancel();
    _noticeTimer = Timer(duration, () {
      if (mounted) {
        setState(() {
          _notice = null;
          _granel = null;
        });
      }
    });
  }

  bool _fresh(DateTime at) => DateTime.now().difference(at) <= _waitFor;

  /// A etiqueta de granel sem código, enquanto o aviso dela está na tela: o
  /// aviso vira botão para escolher o produto (ADR 0018).
  TagPriceRead? _granel;

  Future<void> _chooseGranel() async {
    final read = _granel;
    if (read == null) return;
    final l10n = AppLocalizations.of(context);
    final createProduct = ref.read(createProductByWeightProvider);
    _noticeTimer?.cancel();
    setState(() {
      _notice = null;
      _granel = null;
    });
    final choice = await _withAnalysisPaused(
      () => pickProduct(
        context,
        initialQuery: read.nameHint ?? '',
        title: l10n.cartGranelTitle(l10n.pricePerKilo(read.price.format())),
      ),
    );
    if (choice == null || !mounted) return;
    final product = switch (choice) {
      ExistingProduct(product: final chosen) => chosen,
      NewProduct(:final name) => await createProduct(name),
    };
    await _confirm(product, null, read);
  }

  Future<void> _onEvent(LiveScanEvent event) async {
    switch ((event, _mode)) {
      case (final TagPriceRead tag, CameraMode.price):
        await _onTag(tag);
      case (ProductScanned(:final barcode), _):
        await _onCode(barcode);
      case (TagPriceRead(), _):
        // Fora de "Etiqueta", a etiqueta não faz nada.
        break;
    }
  }

  /// A embalagem do código, com o produto; um código novo abre "Embalagem
  /// nova" (com o nome e o preço da etiqueta, se houver).
  Future<NewPackage?> _resolve(String code, {TagPriceRead? tag, bool register = true}) async {
    final repository = ref.read(productRepositoryProvider);
    final package = await repository.findPackageByBarcode(code);
    final product = package == null ? null : await repository.findById(package.productId);
    if (package != null && product != null) return (product: product, package: package);
    if (!register || !mounted) return null;
    return _withAnalysisPaused(
      () => showNewPackageSheet(context, ref, barcode: code, nameHint: tag?.nameHint, price: tag?.price),
    );
  }

  Future<void> _onCode(String code) async {
    final l10n = AppLocalizations.of(context);
    // O código da balança muda a cada pesagem: só vale no carrinho (ADR 0018).
    if (ScaleLabel.isScaleCode(code)) {
      _showNotice((icon: Icons.scale_outlined, value: null, detail: l10n.cameraScaleCode, waiting: false));
      return;
    }
    // Dar baixa num código que nem está cadastrado não tem o que tirar.
    final scanned = await _resolve(code, register: _mode != CameraMode.used);
    if (!mounted) return;
    if (scanned == null) {
      if (_mode == CameraMode.used) {
        _showNotice((icon: Icons.remove_rounded, value: null, detail: l10n.cameraUnknownCode, waiting: false));
      }
      return;
    }
    _cameraKey.currentState?.lock();
    unawaited(HapticFeedback.mediumImpact());
    final (:product, :package) = scanned;
    switch (_mode) {
      case CameraMode.find:
        await GoRouter.of(context).pushReplacement<void>(Routes.productDetail(product.id));
      case CameraMode.bought:
        await _adjust(product, package, 1);
      case CameraMode.used:
        await _adjust(product, package, -1);
      case CameraMode.price:
        final pending = _pendingTag;
        if (pending != null && _fresh(pending.at)) {
          _pendingTag = null;
          await _confirm(product, package, pending.read);
        } else {
          _pendingProduct = (product: product, package: package, at: DateTime.now());
          _showNotice(
            (icon: Icons.sell_outlined, value: null, detail: l10n.cameraWaitingTag(product.name), waiting: true),
            duration: _waitFor,
          );
        }
    }
  }

  Future<void> _onTag(TagPriceRead read) async {
    final l10n = AppLocalizations.of(context);
    final barcode = read.barcode;
    // A etiqueta da balança entra pelo código, no carrinho (ADR 0018).
    if (barcode != null && ScaleLabel.isScaleCode(barcode)) return;
    if (barcode != null) {
      final scanned = await _resolve(barcode, tag: read);
      if (scanned != null && mounted) await _confirm(scanned.product, scanned.package, read);
      return;
    }
    // Granel sem código: não vem produto bipado. O aviso vira botão.
    if (read.perKilo) {
      unawaited(HapticFeedback.selectionClick());
      _showNotice(
        (
          icon: Icons.sell_outlined,
          value: l10n.pricePerKilo(read.price.format()),
          detail: switch (read.nameHint) {
            final name? => l10n.cartGranelGuess(name),
            null => l10n.cartGranelChoose,
          },
          waiting: false,
        ),
        granel: read,
        duration: _waitFor,
      );
      return;
    }
    final pending = _pendingProduct;
    if (pending != null && _fresh(pending.at)) {
      _pendingProduct = null;
      await _confirm(pending.product, pending.package, read);
      return;
    }
    _pendingTag = (read: read, at: DateTime.now());
    unawaited(HapticFeedback.selectionClick());
    _showNotice(
      (icon: Icons.qr_code_scanner_rounded, value: read.price.format(), detail: l10n.cartLiveWaiting, waiting: true),
      duration: _waitFor,
    );
  }

  Future<void> _confirm(Product product, ProductPackage? package, TagPriceRead read) async {
    if (!mounted) return;
    // O que esperava foi usado (ou ficou para trás): não vai para a próxima leitura.
    _pendingTag = null;
    _pendingProduct = null;
    _cameraKey.currentState?.lock();
    unawaited(HapticFeedback.mediumImpact());
    setState(() => _notice = null);
    final saved = await _withAnalysisPaused(
      () => showConfirmPriceSheet(
        context,
        reading: (
          product: product,
          package: package,
          price: read.price,
          otherOffers: read.otherOffers,
          source: PriceSource.priceTag,
          perKilo: read.perKilo,
        ),
        marketId: _market?.id,
        chooseMarket: () async {
          await _chooseMarket();
          return _market?.id;
        },
      ),
    );
    if (saved && mounted) {
      final l10n = AppLocalizations.of(context);
      _showNotice((
        icon: Icons.check_rounded,
        value: read.perKilo ? l10n.pricePerKilo(read.price.format()) : read.price.format(),
        detail: l10n.cameraPriceSaved(CartEntry.nameOf(product, package)),
        waiting: false,
      ));
    }
  }

  /// "Comprei" ou "Dar baixa": uma embalagem a mais ou a menos em casa, com
  /// Desfazer.
  Future<void> _adjust(Product product, ProductPackage package, int delta) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(stockRepositoryProvider);
    final current = (await repository.findByProduct(product.id))?.quantity ?? 0;
    final applied = StockItem.nextQuantity(current, delta.toDouble()) - current;
    if (applied == 0) {
      _showNotice((icon: Icons.remove_rounded, value: null, detail: l10n.cameraNotAtHome(product.name), waiting: false));
      return;
    }
    final change = await repository.adjust(
      productId: product.id,
      packageId: package.id,
      delta: applied,
      reason: applied > 0 ? StockMovementReason.purchase : StockMovementReason.consumption,
    );
    if (!mounted) return;
    final amount = Formatters.quantity(applied.abs());
    _showNotice((
      icon: applied > 0 ? Icons.add_rounded : Icons.remove_rounded,
      value: applied > 0 ? l10n.cameraDeltaUp(amount) : l10n.cameraDeltaDown(amount),
      detail: l10n.cameraAtHome(product.name, Formatters.quantity(current + applied)),
      waiting: false,
    ));
    // Com menos de uma embalagem em casa, a baixa tira só o que havia.
    final done = switch (applied) {
      > 0.0 => l10n.stockBoughtOneDone(product.name),
      -1.0 => l10n.stockUsedOneDone(product.name),
      _ => l10n.cameraUsedPart(amount, product.name),
    };
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(done),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(label: l10n.undo, onPressed: () => repository.revert(change)),
        ),
      );
  }

  /// A compra abre o carrinho por cima da Lista, e esta câmera sai: ela fecha
  /// antes, para o carrinho achar a câmera livre. Se a compra não começar, a
  /// câmera volta.
  Future<void> _goShopping() async {
    final camera = _cameraKey.currentState;
    await camera?.stop();
    if (!mounted) return;
    try {
      await startShopping(context, ref);
    } on Exception catch (error, stack) {
      FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack, library: 'camera'));
      await camera?.resume();
    }
  }

  String _hint(AppLocalizations l10n) => switch (_mode) {
    CameraMode.price => l10n.cartHint,
    CameraMode.find => l10n.cameraHintCode,
    CameraMode.bought => l10n.cameraHintBought,
    CameraMode.used => l10n.cameraHintUsed,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final notice = _notice;
    final choosing = _mode == CameraMode.price || _mode == CameraMode.find;

    return Scaffold(
      backgroundColor: colors.camera,
      body: LiveCamera(
        key: _cameraKey,
        onEvent: _onEvent,
        hint: _hint(l10n),
        notice: switch (notice) {
          (:final icon, :final value, :final detail, :final waiting)? => LiveReadChip(
            key: ValueKey((value, detail)),
            icon: icon,
            price: value,
            detail: detail,
            countdown: waiting ? _waitFor : null,
            onTap: _granel == null ? null : _chooseGranel,
          ),
          null => null,
        },
        topBar: (camera) => Row(
          children: [
            CameraGlassButton(icon: Icons.close_rounded, label: l10n.cartClose, onPressed: () => context.pop()),
            const SizedBox(width: BipaSpacing.s2),
            Expanded(
              child: Center(
                // O mercado só importa para o preço.
                child: _mode == CameraMode.price
                    ? CameraGlassChip(
                        icon: Icons.storefront_outlined,
                        label: _market?.name ?? l10n.cartChooseMarket,
                        onTap: _chooseMarket,
                      )
                    : null,
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
        bottom: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(BipaSpacing.s6, 0, BipaSpacing.s6, BipaSpacing.s6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (choosing) ...[
                  CameraModeSwitch<CameraMode>(
                    options: [
                      (value: CameraMode.price, label: l10n.cameraModeTag),
                      (value: CameraMode.find, label: l10n.cameraModeCode),
                    ],
                    selected: _mode,
                    onSelected: (mode) => setState(() {
                      _mode = mode;
                      _pendingTag = null;
                      _pendingProduct = null;
                      _notice = null;
                    }),
                  ),
                  const SizedBox(height: BipaSpacing.s6),
                ],
                if (_mode == CameraMode.price)
                  Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: CameraGlassButton(
                            icon: Icons.keyboard_alt_outlined,
                            label: l10n.cartTypePrice,
                            // O formulário de sempre, para digitar tudo.
                            onPressed: () => _withScannerPaused(() => context.push<void>(Routes.capturePrice)),
                          ),
                        ),
                      ),
                      ShutterButton(
                        label: l10n.cartPhotoTag,
                        onPressed: () => _withScannerPaused(() => context.push<void>(Routes.capturePricePhoto)),
                      ),
                      Expanded(
                        child: Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: CameraGlassButton(
                            icon: Icons.shopping_cart_outlined,
                            label: l10n.scanMenuCart,
                            onPressed: _goShopping,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
