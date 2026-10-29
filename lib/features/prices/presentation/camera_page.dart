import 'dart:async';

import 'package:bipa/core/design_system/bipa_metrics.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/design_system/components/camera_mode_switch.dart';
import 'package:bipa/core/design_system/components/scan_menu.dart';
import 'package:bipa/core/design_system/components/scan_tray.dart';
import 'package:bipa/core/formatting/formatters.dart';
import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/core/location/location_service.dart';
import 'package:bipa/core/money/money.dart';
import 'package:bipa/core/navigation/routes.dart';
import 'package:bipa/core/widgets/price_dialog.dart';
import 'package:bipa/features/markets/domain/market.dart';
import 'package:bipa/features/markets/presentation/market_picker_sheet.dart';
import 'package:bipa/features/markets/presentation/markets_providers.dart';
import 'package:bipa/features/prices/domain/price_source.dart';
import 'package:bipa/features/prices/domain/price_tag.dart';
import 'package:bipa/features/prices/presentation/confirm_price_sheet.dart';
import 'package:bipa/features/prices/presentation/prices_providers.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/products/domain/product_package.dart';
import 'package:bipa/features/products/domain/scale_label.dart';
import 'package:bipa/features/products/presentation/new_package_sheet.dart';
import 'package:bipa/features/products/presentation/product_picker_sheet.dart';
import 'package:bipa/features/products/presentation/products_providers.dart';
import 'package:bipa/features/shopping_list/domain/cart_item.dart';
import 'package:bipa/features/shopping_list/domain/live_scan.dart';
import 'package:bipa/features/shopping_list/domain/record_at_home.dart';
import 'package:bipa/features/shopping_list/presentation/home_change_snack_bar.dart';
import 'package:bipa/features/shopping_list/presentation/live_camera.dart';
import 'package:bipa/features/shopping_list/presentation/photograph_tag.dart';
import 'package:bipa/features/shopping_list/presentation/shopping_list_providers.dart';
import 'package:bipa/features/shopping_list/presentation/start_shopping.dart';
import 'package:bipa/features/stock/domain/stock_location.dart';
import 'package:bipa/features/stock/presentation/place_choice_sheet.dart';
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

/// Como completar o produto que esperava a etiqueta.
enum _Complete { typePrice, keep }

/// O que a câmera mostra abaixo da moldura depois de uma leitura.
typedef _Notice = ({IconData icon, String? value, String detail, bool waiting});

/// A câmera do botão de bipar (protótipo "Captura"): abre direto, lendo ao
/// vivo como o modo carrinho (ADR 0012). Em "Etiqueta", o preço lido abre a
/// folha de conferir e salvar; em "Código", o produto. Pelo menu do bipar e
/// pelo Início vazio, os mesmos bipes dão baixa ou somam em casa, um atrás
/// do outro. O mercado fica no chip do topo e só é pedido no "Salvar".
class CameraPage extends ConsumerStatefulWidget {
  const CameraPage({this.mode = CameraMode.price, this.productId, this.packageId, super.key});

  final CameraMode mode;

  /// "Registrar preço" na tela do produto: ele espera a etiqueta sem prazo,
  /// e a câmera volta para a tela dele depois de salvar. Com [packageId], o
  /// preço é daquela embalagem.
  final String? productId;
  final String? packageId;

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

  /// O produto aberto pela tela dele ([CameraPage.productId]), que espera a
  /// etiqueta enquanto a câmera estiver aberta.
  ({Product product, ProductPackage? package})? _held;

  _Notice? _notice;
  Timer? _noticeTimer;

  @override
  void initState() {
    super.initState();
    unawaited(_detectMarket());
    if (widget.productId case final productId?) unawaited(_loadHeld(productId, widget.packageId));
  }

  /// O produto da tela dele e a embalagem escolhida; sem ela, a mais recente
  /// do produto, como fazia o formulário antigo.
  Future<void> _loadHeld(String productId, String? packageId) async {
    final repository = ref.read(productRepositoryProvider);
    try {
      final product = await repository.findById(productId);
      if (product == null) {
        // Apagado nesse meio-tempo: a câmera volta a ser a de sempre.
        if (mounted) setState(() => _heldGone = true);
        return;
      }
      final chosen = packageId == null ? null : await repository.findPackageById(packageId);
      final package = chosen?.productId == productId
          ? chosen
          : (await repository.watchPackages(productId).first).firstOrNull;
      if (mounted) setState(() => _held = (product: product, package: package));
    } on Exception catch (error, stack) {
      FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack, library: 'camera'));
      if (mounted) setState(() => _heldGone = true);
    }
  }

  /// O produto pedido não carregou: sem ele, a câmera não fica presa a nada.
  var _heldGone = false;

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

  /// [onTap] faz do aviso um botão (com a seta): o granel a escolher, ou a
  /// leitura pela metade a completar. Com [actionLabel], o botão diz o que
  /// faz no lugar da seta ("Desfazer"). [onDetailTap] faz do texto um botão
  /// à parte: o local do item novo (AB9).
  void _showNotice(
    _Notice notice, {
    VoidCallback? onTap,
    String? actionLabel,
    VoidCallback? onDetailTap,
    Duration duration = const Duration(milliseconds: 2500),
  }) {
    if (!mounted) return;
    setState(() {
      _notice = notice;
      _noticeTap = onTap;
      _noticeAction = actionLabel;
      _noticeDetailTap = onDetailTap;
    });
    _noticeTimer?.cancel();
    _noticeTimer = Timer(duration, _clearNotice);
  }

  void _clearNotice() {
    _noticeTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _notice = null;
      _noticeTap = null;
      _noticeAction = null;
      _noticeDetailTap = null;
    });
  }

  bool _fresh(DateTime at) => DateTime.now().difference(at) <= _waitFor;

  /// O que tocar no aviso faz, enquanto ele está na tela.
  VoidCallback? _noticeTap;

  /// O que o aviso diz que o toque faz, no lugar da seta.
  String? _noticeAction;

  /// O que tocar no texto do aviso faz, quando ele é um botão à parte.
  VoidCallback? _noticeDetailTap;

  /// Tocou no aviso do granel: escolhe o produto pelo nome lido (ADR 0018).
  Future<void> _chooseGranel(TagPriceRead read) async {
    final l10n = AppLocalizations.of(context);
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
    final messenger = ScaffoldMessenger.of(context);
    final Product product;
    try {
      product = switch (choice) {
        ExistingProduct(product: final chosen) => chosen,
        NewProduct(:final name) => await createProduct(name),
      };
    } on Exception {
      messenger.showSnackBar(SnackBar(content: Text(l10n.capturePriceFailed)));
      return;
    }
    await _confirmTag(product, null, read);
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
        await _adjust(product, package, bought: true);
      case CameraMode.used:
        await _adjust(product, package, bought: false);
      case CameraMode.price:
        final pending = _pendingTag;
        if (pending != null && _fresh(pending.at)) {
          _pendingTag = null;
          await _confirmTag(product, package, pending.read);
        } else {
          _pendingProduct = (product: product, package: package, at: DateTime.now());
          // Etiqueta amassada ou longe: tocar no aviso completa sem ela (D5).
          _showNotice(
            (icon: Icons.sell_outlined, value: null, detail: l10n.cameraWaitingTag(product.name), waiting: true),
            onTap: () => _completeProduct(product, package),
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
      if (scanned != null && mounted) await _confirmTag(scanned.product, scanned.package, read);
      return;
    }
    // Granel sem código: não vem produto bipado. Aberta pela tela de um
    // produto, a etiqueta é dele; senão, o aviso vira botão.
    if (read.perKilo) {
      if (_held case (:final product, package: _)?) {
        await _confirmTag(product, null, read);
        return;
      }
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
        onTap: () => _chooseGranel(read),
        duration: _waitFor,
      );
      return;
    }
    final pending = _pendingProduct;
    if (pending != null && _fresh(pending.at)) {
      _pendingProduct = null;
      await _confirmTag(pending.product, pending.package, read);
      return;
    }
    if (_held case (:final product, :final package)?) {
      await _confirmTag(product, package, read);
      return;
    }
    _pendingTag = (read: read, at: DateTime.now());
    unawaited(HapticFeedback.selectionClick());
    // Código fora de alcance: tocar no aviso escolhe o produto pelo nome (D5).
    _showNotice(
      (icon: Icons.qr_code_scanner_rounded, value: read.price.format(), detail: l10n.cartLiveWaiting, waiting: true),
      onTap: () => _chooseProductFor(read),
      duration: _waitFor,
    );
  }

  /// Tocou no aviso do produto que esperava a etiqueta: digitar o preço ou,
  /// em casa, guardar uma embalagem (AB7).
  Future<void> _completeProduct(Product product, ProductPackage? package) async {
    final l10n = AppLocalizations.of(context);
    _clearNotice();
    final choice = await _withAnalysisPaused(
      () => showScanMenu<_Complete>(
        context,
        closeLabel: l10n.scanMenuClose,
        items: [
          (value: _Complete.typePrice, icon: Icons.keyboard_alt_outlined, label: l10n.cartTypePrice, hint: null),
          (value: _Complete.keep, icon: Icons.add_home_outlined, label: l10n.scanMenuBought, hint: null),
        ],
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case _Complete.typePrice:
        await _typePriceFor(product, package);
      case _Complete.keep:
        _pendingProduct = null;
        await _adjust(product, package, bought: true);
      case null:
        break;
    }
  }

  /// Tocou no aviso do preço que esperava o produto: escolhe pelo nome lido.
  Future<void> _chooseProductFor(TagPriceRead read) async {
    final l10n = AppLocalizations.of(context);
    _clearNotice();
    final choice = await _withAnalysisPaused(
      () => pickProduct(context, allowCreate: false, initialQuery: read.nameHint ?? '', title: l10n.cameraWhichProduct),
    );
    if (choice is! ExistingProduct || !mounted) return;
    await _confirmTag(choice.product, null, read);
  }

  /// O teclado: digita o preço do produto que espera a etiqueta, ou de um
  /// escolhido pelo nome, e confere na mesma folha da etiqueta.
  Future<void> _typePrice() async {
    final pending = _pendingProduct;
    if (pending != null && _fresh(pending.at)) return _typePriceFor(pending.product, pending.package);
    if (_held case (:final product, :final package)?) return _typePriceFor(product, package);
    final l10n = AppLocalizations.of(context);
    final choice = await _withAnalysisPaused(
      () => pickProduct(context, allowCreate: false, title: l10n.cameraWhichProduct),
    );
    if (choice is! ExistingProduct || !mounted) return;
    await _typePriceFor(choice.product, null);
  }

  Future<void> _typePriceFor(Product product, ProductPackage? package) async {
    final l10n = AppLocalizations.of(context);
    _clearNotice();
    final price = await _withAnalysisPaused(
      () => showPriceDialog(context, title: l10n.cartPriceTitle(CartEntry.nameOf(product, package))),
    );
    if (price == null || !mounted) return;
    await _confirm(product, package, price: price, source: PriceSource.manual);
  }

  /// O disparo: fotografa pela câmera ao vivo e segue como a leitura ao vivo.
  Future<void> _shoot() async {
    // Dois toques seguidos no disparo não tiram duas fotos nem abrem duas folhas.
    if (_shooting) return;
    _shooting = true;
    try {
      await _photograph();
    } finally {
      _shooting = false;
    }
  }

  var _shooting = false;

  Future<void> _photograph() async {
    final camera = _cameraKey.currentState;
    if (camera == null) return;
    final l10n = AppLocalizations.of(context);
    final reader = ref.read(priceTagReaderProvider);
    unawaited(HapticFeedback.mediumImpact());
    final TagPriceRead? read;
    try {
      read = await camera.withAnalysisPaused(() => photographTag(camera, reader));
    } on Exception catch (error, stack) {
      FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack, library: 'camera'));
      _showNotice((icon: Icons.sell_outlined, value: null, detail: l10n.cameraPhotoNoPrice, waiting: false));
      return;
    }
    if (!mounted) return;
    if (read == null) {
      _showNotice((icon: Icons.sell_outlined, value: null, detail: l10n.cameraPhotoNoPrice, waiting: false));
      return;
    }
    await _onTag(read);
  }

  Future<void> _confirmTag(Product product, ProductPackage? package, TagPriceRead read) => _confirm(
    product,
    package,
    price: read.price,
    source: PriceSource.priceTag,
    otherOffers: read.otherOffers,
    perKilo: read.perKilo,
  );

  /// A folha "Conferir e salvar", com o preço lido ou digitado.
  Future<void> _confirm(
    Product product,
    ProductPackage? package, {
    required Money price,
    required PriceSource source,
    List<PriceOffer> otherOffers = const [],
    bool perKilo = false,
  }) async {
    if (!mounted) return;
    // O que esperava foi usado (ou ficou para trás): não vai para a próxima leitura.
    _pendingTag = null;
    _pendingProduct = null;
    _cameraKey.currentState?.lock();
    unawaited(HapticFeedback.mediumImpact());
    _clearNotice();
    final saved = await _withAnalysisPaused(
      () => showConfirmPriceSheet(
        context,
        reading: (
          product: product,
          package: package,
          price: price,
          otherOffers: otherOffers,
          source: source,
          perKilo: perKilo,
        ),
        market: _market,
        chooseMarket: () async {
          await _chooseMarket();
          return _market;
        },
      ),
    );
    if (saved == null || !mounted) return;
    // O produto e o preço são os que foram salvos: a folha deixa trocar os dois.
    if (_held?.product.id == saved.product.id) {
      // Veio da tela do produto: volta para ela, que já mostra o preço.
      context.pop();
      return;
    }
    final l10n = AppLocalizations.of(context);
    _showNotice((
      icon: Icons.check_rounded,
      value: perKilo ? l10n.pricePerKilo(saved.price.format()) : saved.price.format(),
      detail: l10n.cameraPriceSaved(CartEntry.nameOf(saved.product, saved.package)),
      waiting: false,
    ));
  }

  /// "Comprei" ou "Dar baixa": uma embalagem a mais ou a menos em casa. A
  /// lista acompanha (RecordAtHome), e o Desfazer volta os dois.
  Future<void> _adjust(Product product, ProductPackage? package, {required bool bought}) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final record = ref.read(recordAtHomeProvider);
    final stock = ref.read(stockRepositoryProvider);
    final HomeChange? change;
    final wasNew = bought && await stock.findByProduct(product.id) == null;
    if (!mounted) return;
    try {
      change = bought
          ? await record.bought(product, packageId: package?.id)
          : await record.used(product, packageId: package?.id);
    } on Exception {
      if (mounted) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.cameraAdjustFailed)));
      }
      return;
    }
    if (!mounted) return;
    if (change == null) {
      _showNotice((
        icon: Icons.remove_rounded,
        value: null,
        detail: l10n.cameraNotAtHome(product.name),
        waiting: false,
      ));
      return;
    }
    final applied = change.stock.applied;
    final item = await stock.findByProduct(product.id);
    if (!mounted) return;
    final atHome = item?.quantity ?? 0;
    final amount = Formatters.quantity(applied.abs());
    final homeChange = change;
    Future<void> undo() async {
      _clearNotice();
      try {
        await record.undo(homeChange);
      } on Exception {
        messenger.showSnackBar(SnackBar(content: Text(l10n.cameraAdjustFailed)));
      }
    }

    // Só o estoque mudou, e o aviso já diz isso: o Desfazer fica nele, sem
    // repetir o fato num snackbar que esconderia o do bipe anterior (D7).
    final undoInNotice = change.list is ListUnchanged;

    // O aviso do bipe. Com o local, o item nasceu agora: o texto diz onde
    // ele ficou e é um botão que troca o local (AB9), e o aviso volta com o
    // local novo depois da escolha.
    void show(StockLocation? place) => _showNotice(
      (
        icon: applied > 0 ? Icons.add_rounded : Icons.remove_rounded,
        value: applied > 0 ? l10n.cameraDeltaUp(amount) : l10n.cameraDeltaDown(amount),
        detail: place == null
            ? l10n.cameraAtHome(product.name, Formatters.quantity(atHome))
            : l10n.cameraAtHomePlaced(product.name, Formatters.quantity(atHome), place.name),
        waiting: false,
      ),
      onTap: undoInNotice ? () => unawaited(undo()) : null,
      actionLabel: undoInNotice ? l10n.undo : null,
      onDetailTap: place == null ? null : () => unawaited(_choosePlace(product, place, show)),
      duration: undoInNotice || place != null ? _undoFor : const Duration(milliseconds: 2500),
    );

    // O local só é dito quando o item nasce neste bipe (AB9): é a hora em que
    // a sugestão pode estar errada e a pessoa ainda lembra do que bipou.
    show(wasNew ? item?.location : null);
    if (undoInNotice) return;
    // O aviso mostra o estoque; o snackbar diz o que mudou na lista, que é o
    // que o Desfazer também volta.
    showHomeChangeSnackBar(messenger, l10n: l10n, record: record, product: product, change: change);
  }

  /// Tocou no local do aviso: o tempo do aviso para, a folha "Onde fica"
  /// abre com o local atual marcado, e o aviso volta com o escolhido. O
  /// local fica no item (ADR 0021).
  Future<void> _choosePlace(Product product, StockLocation current, void Function(StockLocation) show) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final stock = ref.read(stockRepositoryProvider);
    _noticeTimer?.cancel();
    final chosen = await _withAnalysisPaused(
      () => pickStockLocation(context, productName: product.name, current: current),
    );
    if (!mounted) return;
    var place = current;
    if (chosen != null && chosen != current) {
      try {
        await stock.setLocation(product.id, chosen);
        place = chosen;
      } on Exception {
        messenger.showSnackBar(SnackBar(content: Text(l10n.stockAdjustFailed)));
      }
    }
    if (!mounted) return;
    show(place);
  }

  /// Quanto tempo o Desfazer fica no aviso do visor, como num snackbar.
  static const _undoFor = Duration(seconds: 4);

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
    final held = _held;
    // Sem outro aviso, o produto da tela dele espera a etiqueta; tocar digita
    // o preço (D5).
    final _Notice? heldNotice = held == null
        ? null
        : (icon: Icons.sell_outlined, value: null, detail: l10n.cameraWaitingTag(held.product.name), waiting: false);
    final notice = _notice ?? heldNotice;
    final VoidCallback? noticeTap = switch ((_notice, held)) {
      (null, (:final product, :final package)?) => () => _typePriceFor(product, package),
      _ => _noticeTap,
    };
    // Aberta para um produto, a câmera só lê a etiqueta dele.
    final forProduct = held != null || (widget.productId != null && !_heldGone);
    final choosing = !forProduct && (_mode == CameraMode.price || _mode == CameraMode.find);
    // Observado enquanto a câmera está aberta: o leitor do disparo carrega os
    // modelos do ML Kit uma vez e os solta ao sair.
    ref.watch(priceTagReaderProvider);

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
            onTap: noticeTap,
            actionLabel: _notice == null ? null : _noticeAction,
            onDetailTap: _notice == null ? null : _noticeDetailTap,
            detailActionLabel: l10n.cameraChangePlace,
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
                            onPressed: _typePrice,
                          ),
                        ),
                      ),
                      ShutterButton(label: l10n.cartPhotoTag, onPressed: _shoot),
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
