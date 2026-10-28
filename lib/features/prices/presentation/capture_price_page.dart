import 'dart:async';
import 'dart:io';

import 'package:bipa/core/errors/domain_exception.dart';
import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/core/l10n/meta_join.dart';
import 'package:bipa/core/location/location_service.dart';
import 'package:bipa/core/money/money.dart';
import 'package:bipa/core/navigation/routes.dart';
import 'package:bipa/core/widgets/messages.dart';
import 'package:bipa/features/markets/domain/market.dart';
import 'package:bipa/features/markets/presentation/market_picker_sheet.dart';
import 'package:bipa/features/markets/presentation/markets_providers.dart';
import 'package:bipa/features/prices/domain/price_condition.dart';
import 'package:bipa/features/prices/domain/price_source.dart';
import 'package:bipa/features/prices/domain/price_tag.dart';
import 'package:bipa/features/prices/domain/register_price_observation.dart';
import 'package:bipa/features/prices/presentation/price_condition_label.dart';
import 'package:bipa/features/prices/presentation/prices_providers.dart';
import 'package:bipa/features/products/domain/gtin.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/products/domain/product_package.dart';
import 'package:bipa/features/products/domain/scale_label.dart';
import 'package:bipa/features/products/presentation/products_providers.dart';
import 'package:bipa/features/shopping_list/domain/cart_item.dart';
import 'package:bipa/features/shopping_list/presentation/shopping_list_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

/// Fluxo principal do app: registrar um preço no mercado com o mínimo de
/// digitação.
///
/// 1. O mercado é detectado pela localização.
/// 2. A foto da etiqueta preenche preço, código de barras e nome.
/// 3. O usuário confere e salva; "Salvar e bipar outro" agiliza a sequência.
class CapturePricePage extends ConsumerStatefulWidget {
  const CapturePricePage({this.productId, this.packageId, this.fromCart = false, super.key});

  /// Quando informado, registra o preço deste produto (vindo da tela dele).
  final String? productId;

  /// A embalagem do preço, quando aberto por uma linha de "Embalagens".
  final String? packageId;

  /// Aberta pelo disparo do modo carrinho: o produto vai para o carrinho
  /// com o preço lido e é marcado na lista.
  final bool fromCart;

  @override
  ConsumerState<CapturePricePage> createState() => _CapturePricePageState();
}

class _CapturePricePageState extends ConsumerState<CapturePricePage> {
  final _formKey = GlobalKey<FormState>();

  /// Vindo do modo carrinho: os itens ([CartItem.key]) cujo preço esta tela
  /// pôs no carrinho.
  final _pricedInCart = <String>{};
  final _barcode = TextEditingController();
  final _name = TextEditingController();
  final _price = TextEditingController();
  final _regularPrice = TextEditingController();

  Market? _market;
  var _marketDetected = false;
  var _detectingMarket = true;

  /// Produto já cadastrado que corresponde ao código de barras, e a
  /// embalagem com esse código (ADR 0013).
  Product? _product;
  ProductPackage? _package;
  String? _photoPath;
  List<Money> _candidates = const [];

  /// Preço principal lido da etiqueta e os outros preços dela (ADR 0011).
  PriceOffer? _mainOffer;
  List<PriceOffer> _otherOffers = const [];
  final _selectedOffers = <PriceOffer>{};
  var _source = PriceSource.manual;
  var _reading = false;
  var _saving = false;

  bool get _productLocked => widget.productId != null;

  @override
  void initState() {
    super.initState();
    unawaited(_detectMarket());
    final productId = widget.productId;
    if (productId != null) unawaited(_loadProduct(productId));
  }

  @override
  void dispose() {
    _barcode.dispose();
    _name.dispose();
    _price.dispose();
    _regularPrice.dispose();
    super.dispose();
  }

  /// Produto fixo (aberto pelo detalhe do produto): o preço vai para a
  /// embalagem escolhida ou, sem ela, para a mais recente dele.
  Future<void> _loadProduct(String id) async {
    final repository = ref.read(productRepositoryProvider);
    final product = await repository.findById(id);
    final packageId = widget.packageId;
    final found = packageId == null ? null : await repository.findPackageById(packageId);
    // Só vale a embalagem que é deste produto.
    final chosen = found?.productId == id ? found : null;
    final package = chosen ?? (await repository.watchPackages(id).first).firstOrNull;
    if (!mounted) return;
    setState(() {
      _product = product;
      _package = package;
    });
  }

  Future<void> _detectMarket() async {
    // Abrir a tela não pede a localização: sem ela, o mercado é escolhido no
    // chip.
    final location = await ref.read(locationServiceProvider).currentLocation(request: false);
    Market? detected;
    if (location is LocationFound) {
      final markets = await ref.read(marketRepositoryProvider).all();
      detected = ref.read(nearestMarketFinderProvider).marketAt(location.point, markets);
    }
    if (!mounted) return;
    setState(() {
      _detectingMarket = false;
      // Não sobrescreve uma escolha que o usuário já tenha feito.
      if (_market == null && detected != null) {
        _market = detected;
        _marketDetected = true;
      }
    });
  }

  Future<void> _chooseMarket() async {
    final selected = await pickMarket(context, selectedId: _market?.id);
    if (selected != null && mounted) {
      setState(() {
        _market = selected;
        _marketDetected = false;
      });
    }
  }

  Future<void> _photographTag(PriceTagReader reader) async {
    final XFile? photo;
    try {
      photo = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 2048,
        imageQuality: 90,
      );
    } on Exception {
      if (mounted) context.showMessage(AppLocalizations.of(context).captureCameraFailed);
      return;
    }
    if (photo == null || !mounted) return;

    // Variável local não-nula: a promoção de `photo` não vale dentro de closures.
    final path = photo.path;
    setState(() {
      _photoPath = path;
      _reading = true;
    });
    try {
      final reading = await reader.read(path);
      if (mounted) _applyReading(reading);
    } on Exception {
      if (mounted) {
        context.showMessage(AppLocalizations.of(context).captureReadFailed);
      }
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  void _applyReading(PriceTagReading reading) {
    // O código da balança muda a cada pesagem: não identifica o produto
    // (ADR 0018).
    final barcode = switch (reading.barcode) {
      final code? when !ScaleLabel.isScaleCode(code) => code,
      _ => null,
    };
    setState(() {
      _source = PriceSource.priceTag;
      _candidates = reading.candidates;
      _mainOffer = reading.offers.firstOrNull;
      _otherOffers = reading.offers.skip(1).toList(growable: false);
      _selectedOffers
        ..clear()
        ..addAll(_otherOffers);
      _price.text = reading.price?.formatDecimal() ?? _price.text;
      _regularPrice.text = reading.regularPrice?.formatDecimal() ?? '';
      if (!_productLocked && barcode != null) _barcode.text = barcode;
      if (_name.text.trim().isEmpty) _name.text = reading.productNameHint ?? '';
    });

    if (!_productLocked && barcode != null) unawaited(_lookupBarcode(barcode));
    if (reading.price == null && reading.candidates.isNotEmpty) {
      context.showMessage(AppLocalizations.of(context).captureChoosePrice);
    } else if (reading.isEmpty) {
      context.showMessage(AppLocalizations.of(context).captureNoPrice);
    }
  }

  Future<void> _scanBarcode() async {
    final code = await context.push<String>(Routes.scanner);
    if (code == null || !mounted) return;
    _barcode.text = code;
    await _lookupBarcode(code);
  }

  void _onBarcodeChanged(String value) {
    final code = value.trim();
    if (_product != null && _package?.barcode != code) {
      setState(() {
        _product = null;
        _package = null;
      });
    }
    if (Gtin.isValid(code)) unawaited(_lookupBarcode(code));
  }

  Future<void> _lookupBarcode(String code) async {
    final repository = ref.read(productRepositoryProvider);
    final package = await repository.findPackageByBarcode(code);
    final product = package == null ? null : await repository.findById(package.productId);
    if (mounted && _barcode.text.trim() == code) {
      setState(() {
        _product = product;
        _package = product == null ? null : package;
      });
    }
  }

  Future<void> _save({required bool captureAnother}) async {
    final market = _market;
    if (market == null) {
      context.showMessage(AppLocalizations.of(context).captureMarketMissing);
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final price = Money.tryParse(_price.text)!;
    final barcode = _barcode.text.trim();
    setState(() => _saving = true);

    // Lidos antes dos awaits: a tela pode fechar no meio do caminho.
    final trips = ref.read(shoppingTripRepositoryProvider);
    final list = ref.read(shoppingListRepositoryProvider);
    final cart = ref.read(cartRepositoryProvider);
    try {
      final observation = await ref.read(registerPriceObservationProvider).call(
        RegisterPriceInput(
          marketId: market.id,
          price: price,
          regularPrice: Money.tryParse(_regularPrice.text),
          condition: _mainCondition,
          otherOffers: [
            for (final offer in _otherOffers)
              if (_selectedOffers.contains(offer)) offer,
          ],
          source: _source,
          productId: _product?.id,
          packageId: _package?.id,
          barcode: barcode.isEmpty ? null : barcode,
          newProductName: _name.text,
        ),
      );
      // Vindo do modo carrinho, o produto vai para o carrinho com o preço
      // lido (sem somar unidade, se ele já foi bipado) e é marcado na lista.
      // O preço já foi salvo: uma falha aqui não pode parecer falha ao salvar.
      try {
        if (widget.fromCart) {
          if (await trips.watchActive().first case final trip?) {
            await cart.setPriceForProduct(
              trip.id,
              observation.productId,
              observation.price,
              packageId: observation.packageId,
            );
            _pricedInCart.add(CartItem.keyOf(observation.productId, observation.packageId));
            await list.checkProduct(observation.productId);
          }
        }
      } on Exception catch (error, stack) {
        FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack, library: 'shopping_list'));
      }
      if (!mounted) return;

      context.showMessage(AppLocalizations.of(context).capturePriceSaved(price.format(), market.name));
      if (captureAnother) {
        _resetForNextItem();
      } else {
        // O modo carrinho recebe os produtos com o preço firmado pela foto.
        context.pop(widget.fromCart ? _pricedInCart : null);
      }
    } on DomainException catch (error) {
      if (mounted) context.showMessage(error.message);
    } on Exception {
      if (mounted) context.showMessage(AppLocalizations.of(context).capturePriceFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _resetForNextItem() {
    _formKey.currentState?.reset();
    setState(() {
      _barcode.clear();
      _name.clear();
      _price.clear();
      _regularPrice.clear();
      _product = null;
      _package = null;
      _photoPath = null;
      _candidates = const [];
      _mainOffer = null;
      _otherOffers = const [];
      _selectedOffers.clear();
      _source = PriceSource.manual;
    });
  }

  /// A condição lida vale enquanto o campo tiver o preço lido. Um preço
  /// digitado ou escolhido entre os outros valores é de varejo.
  PriceCondition get _mainCondition {
    final offer = _mainOffer;
    return offer != null && Money.tryParse(_price.text) == offer.price ? offer.condition : const AnyCustomer();
  }

  String? _validatePrice(String? value) {
    final money = Money.tryParse(value ?? '');
    return money == null || !money.isPositive ? AppLocalizations.of(context).capturePriceMissing : null;
  }

  String? _validateOptionalPrice(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty || Money.tryParse(text) != null ? null : AppLocalizations.of(context).formInvalidValue;
  }

  String? _validateBarcode(String? value) {
    final code = value?.trim() ?? '';
    final l10n = AppLocalizations.of(context);
    if (ScaleLabel.isScaleCode(code)) return l10n.barcodeScale;
    return code.isEmpty || Gtin.isValid(code) ? null : l10n.barcodeInvalid;
  }

  @override
  Widget build(BuildContext context) {
    // Observar o leitor o mantém vivo enquanto esta tela estiver aberta.
    final reader = ref.watch(priceTagReaderProvider);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final offerPrices = {for (final offer in _otherOffers) offer.price};
    final otherValues = [
      for (final candidate in _candidates)
        if (candidate != Money.tryParse(_price.text) && !offerPrices.contains(candidate)) candidate,
    ];
    const priceKeyboard = TextInputType.numberWithOptions(decimal: true);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.captureTitle)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _MarketSelector(
              market: _market,
              detected: _marketDetected,
              detecting: _detectingMarket,
              onTap: _chooseMarket,
            ),
            const SizedBox(height: 16),
            _TagPhotoCard(
              photoPath: _photoPath,
              reading: _reading,
              onCapture: () => _photographTag(reader),
            ),
            if (otherValues.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(l10n.captureOtherValues, style: theme.textTheme.bodySmall),
              Wrap(
                spacing: 8,
                children: [
                  for (final candidate in otherValues)
                    ActionChip(
                      label: Text(candidate.format()),
                      onPressed: () => setState(() => _price.text = candidate.formatDecimal()),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            Text(l10n.captureProduct, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_productLocked)
              _ProductSummary(product: _product, package: _package)
            else ...[
              TextFormField(
                controller: _barcode,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.barcodeLabel,
                  suffixIcon: IconButton(
                    tooltip: l10n.barcodeScan,
                    icon: const Icon(Icons.qr_code_scanner),
                    onPressed: _scanBarcode,
                  ),
                ),
                onChanged: _onBarcodeChanged,
                validator: _validateBarcode,
              ),
              const SizedBox(height: 12),
              if (_product case final product?)
                _ProductSummary(product: product, package: _package)
              else
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: l10n.captureProductName,
                    helperText: l10n.captureNewProduct,
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty) ? l10n.productNameMissing : null,
                ),
            ],
            const SizedBox(height: 24),
            Text(l10n.capturePrice, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _price,
                    keyboardType: priceKeyboard,
                    // Atualiza a condição mostrada e os outros valores.
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: l10n.capturePaid,
                      prefixText: '${Money.symbol} ',
                      helperText: _mainCondition.label(l10n),
                    ),
                    validator: _validatePrice,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _regularPrice,
                    keyboardType: priceKeyboard,
                    decoration: InputDecoration(
                      labelText: l10n.captureRegular,
                      prefixText: '${Money.symbol} ',
                      helperText: l10n.captureRegularHint,
                    ),
                    validator: _validateOptionalPrice,
                  ),
                ),
              ],
            ),
            if (_otherOffers.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(l10n.captureOtherOffers, style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final offer in _otherOffers)
                    FilterChip(
                      label: Text(l10n.joinMeta([offer.price.format(), ?offer.condition.label(l10n)])),
                      selected: _selectedOffers.contains(offer),
                      onSelected: (selected) => setState(() {
                        if (selected) {
                          _selectedOffers.add(offer);
                        } else {
                          _selectedOffers.remove(offer);
                        }
                      }),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _saving ? null : () => _save(captureAnother: false),
              icon: const Icon(Icons.check),
              label: Text(l10n.save),
            ),
            if (!_productLocked) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _saving ? null : () => _save(captureAnother: true),
                icon: const Icon(Icons.document_scanner_outlined),
                label: Text(l10n.captureSaveAndNext),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MarketSelector extends StatelessWidget {
  const _MarketSelector({
    required this.market,
    required this.detected,
    required this.detecting,
    required this.onTap,
  });

  final Market? market;
  final bool detected;
  final bool detecting;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final current = market;
    final l10n = AppLocalizations.of(context);
    final String subtitle;
    if (current == null) {
      subtitle = detecting ? l10n.captureMarketSearching : l10n.captureMarketChoose;
    } else {
      subtitle = detected ? l10n.captureMarketDetected : l10n.captureMarketChange;
    }

    return Card.filled(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(detected ? Icons.where_to_vote : Icons.storefront_outlined),
        title: Text(current?.name ?? l10n.marketPickTitle),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.expand_more),
        onTap: onTap,
      ),
    );
  }
}

class _TagPhotoCard extends StatelessWidget {
  const _TagPhotoCard({required this.photoPath, required this.reading, required this.onCapture});

  final String? photoPath;
  final bool reading;
  final VoidCallback onCapture;

  @override
  Widget build(BuildContext context) {
    final path = photoPath;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Card.outlined(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: reading ? null : onCapture,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (path != null)
              Stack(
                alignment: Alignment.center,
                children: [
                  Image.file(File(path), height: 180, width: double.infinity, fit: BoxFit.cover),
                  if (reading) const CircularProgressIndicator(),
                ],
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.photo_camera_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      path == null ? l10n.capturePhotoHint : (reading ? l10n.captureReading : l10n.capturePhotoAgain),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductSummary extends StatelessWidget {
  const _ProductSummary({required this.product, this.package});

  final Product? product;
  final ProductPackage? package;

  @override
  Widget build(BuildContext context) {
    final current = product;
    final subtitle = package?.label;
    final l10n = AppLocalizations.of(context);
    return Card.outlined(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: const Icon(Icons.check_circle_outline),
        title: Text(current?.name ?? l10n.loading),
        subtitle: Text(subtitle ?? l10n.captureKnownProduct),
      ),
    );
  }
}
