import 'dart:async';

import 'package:bipa/core/design_system/bipa_metrics.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/design_system/bipa_typography.dart';
import 'package:bipa/core/design_system/components/bipa_toast.dart';
import 'package:bipa/core/design_system/components/error_line.dart';
import 'package:bipa/core/design_system/components/price_tag.dart';
import 'package:bipa/core/design_system/components/product_category_icon.dart';
import 'package:bipa/core/design_system/components/product_thumb.dart';
import 'package:bipa/core/design_system/text_scale.dart';
import 'package:bipa/core/errors/domain_exception.dart';
import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/core/l10n/domain_error_text.dart';
import 'package:bipa/core/money/money.dart';
import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:bipa/features/products/domain/package_suggestion.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/products/domain/product_catalog.dart';
import 'package:bipa/features/products/domain/product_package.dart';
import 'package:bipa/features/products/domain/register_package.dart';
import 'package:bipa/features/products/domain/unit_price.dart';
import 'package:bipa/features/products/presentation/package_fields.dart';
import 'package:bipa/features/products/presentation/product_picker_sheet.dart';
import 'package:bipa/features/products/presentation/products_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// O produto e a embalagem que a folha criou.
typedef NewPackage = ({Product product, ProductPackage package});

/// Folha "Embalagem nova" (protótipo "Bipar: embalagem nova"): ao bipar um
/// código que não é de nenhuma embalagem da pessoa, sugere o produto e
/// preenche marca e tamanho, para conferir (ADR 0013).
///
/// O código é procurado antes no catálogo pronto (ADR 0024): achado, a
/// folha vem preenchida com o que ele sabe, e a embalagem nasce marcada
/// como vinda dele. Senão, a sugestão sai do nome lido na etiqueta
/// ([nameHint]), como sem catálogo. [price], quando conhecido, aparece na
/// etiqueta com o preço por kg.
Future<NewPackage?> showNewPackageSheet(
  BuildContext context,
  WidgetRef ref, {
  required String barcode,
  String? nameHint,
  Money? price,
}) async {
  final products = await ref.read(productRepositoryProvider).watchAll().first;
  final fromCatalog = await _findInCatalog(ref, barcode);
  if (!context.mounted) return null;
  return showModalBottomSheet<NewPackage>(
    context: context,
    isScrollControlled: true,
    builder: (_) => BipaSheetToasts(
      child: NewPackageSheet(
        barcode: barcode,
        suggestion: fromCatalog == null
            ? PackageSuggestion.from(nameHint, products: products)
            : PackageSuggestion.fromCatalog(fromCatalog, products: products),
        price: price,
      ),
    ),
  );
}

/// O código no catálogo pronto. Uma falha dele não impede o cadastro: a
/// folha abre como sem catálogo.
Future<CatalogPackage?> _findInCatalog(WidgetRef ref, String barcode) async {
  try {
    return await ref.read(productCatalogProvider).find(barcode);
  } on Exception catch (error) {
    debugPrint('Catálogo pronto: $error');
    return null;
  }
}

class NewPackageSheet extends ConsumerStatefulWidget {
  const NewPackageSheet({required this.barcode, required this.suggestion, this.price, super.key});

  final String barcode;
  final PackageSuggestion suggestion;
  final Money? price;

  @override
  ConsumerState<NewPackageSheet> createState() => _NewPackageSheetState();
}

class _NewPackageSheetState extends ConsumerState<NewPackageSheet> {
  late Product? _product = widget.suggestion.product;
  late String? _newName = widget.suggestion.newProductName;
  late final _brand = TextEditingController(text: widget.suggestion.brand ?? '');
  late final _size = TextEditingController(text: _formatSize(widget.suggestion.size));
  late var _unit = widget.suggestion.unit ?? widget.suggestion.product?.unit ?? MeasureUnit.unit;

  /// A unidade acompanha o produto escolhido até a pessoa escolher outra (ou
  /// até vir do nome lido na etiqueta, "5 kg").
  late var _unitChosen = widget.suggestion.unit != null;
  var _saving = false;
  String? _error;

  String? get _productName => _product?.name ?? _newName;

  double? get _sizeValue => double.tryParse(_size.text.trim().replaceAll(',', '.'));

  @override
  void dispose() {
    _brand.dispose();
    _size.dispose();
    super.dispose();
  }

  static String _formatSize(double? size) => size == null
      ? ''
      : size == size.truncateToDouble()
      ? size.toStringAsFixed(0)
      : '$size'.replaceAll('.', ',');

  /// Com um produto novo sugerido ("Leite condensado semidesnatado", do
  /// catálogo), a busca por todas as palavras não acharia o "Leite" que a
  /// pessoa tem: a escolha abre com o produto parecido, como a da etiqueta
  /// ([productQueryFromLabel]), e "Criar" segue propondo o nome novo (G12).
  Future<void> _chooseProduct() async {
    var query = _productName ?? '';
    final newName = _product == null ? _newName : null;
    if (newName != null && newName.isNotEmpty) {
      try {
        final products = await ref.read(productRepositoryProvider).watchAll().first;
        query = productQueryFromLabel(newName, products: products);
      } on Exception catch (error, stack) {
        // Sem a lista, abre com o nome novo, como antes.
        FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack, library: 'products'));
      }
      if (!mounted) return;
    }
    final choice = await pickProduct(context, initialQuery: query, newName: newName);
    if (choice == null || !mounted) return;
    setState(() {
      switch (choice) {
        case ExistingProduct(:final product):
          _product = product;
          _newName = null;
          if (!_unitChosen) _unit = product.unit;
        case NewProduct(:final name):
          _product = null;
          _newName = name;
      }
      _error = null;
    });
  }

  void _askForProduct() {
    setState(() => _error = AppLocalizations.of(context).packageProductMissing);
    unawaited(_chooseProduct());
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final register = ref.read(registerPackageProvider);
    final sizeText = _size.text.trim();
    final size = _sizeValue;
    if (sizeText.isNotEmpty && size == null) {
      setState(() => _error = l10n.packageSizeInvalid);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final (product, package) = await register(
        NewPackageInput(
          barcode: widget.barcode,
          productId: _product?.id,
          newProductName: _newName,
          brand: _brand.text,
          size: size,
          unit: _unit,
          origin: widget.suggestion.origin,
        ),
      );
      if (mounted) Navigator.of(context).pop((product: product, package: package));
    } on DomainException catch (error) {
      // As regras do domínio viram os textos do ARB.
      if (mounted) setState(() => _error = domainErrorText(l10n, error));
    } on Exception {
      if (mounted) setState(() => _error = l10n.packageSaveFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final name = _productName;
    final price = widget.price;
    final unitPrice = price == null ? null : UnitPrice.of(price: price, packageSize: _sizeValue, unit: _unit);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(BipaSpacing.s4, 0, BipaSpacing.s4, BipaSpacing.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // O produto sugerido; tocar troca.
            Semantics(
              button: true,
              label: name == null ? l10n.packageChooseProduct : l10n.packageNewOfLabel(name, widget.barcode),
              excludeSemantics: true,
              onTap: _chooseProduct,
              child: InkWell(
                onTap: _chooseProduct,
                borderRadius: BorderRadius.circular(BipaRadius.md),
                child: Row(
                  children: [
                    ProductThumb(fallbackIcon: productCategoryIcon(name ?? ''), size: 56, radius: BipaRadius.md),
                    const SizedBox(width: BipaSpacing.s3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (name != null)
                            Text(
                              l10n.packageNewOf.toUpperCase(),
                              style: BipaText.caption.copyWith(color: colors.inkMuted),
                            ),
                          Text(
                            name ?? l10n.packageChooseProduct,
                            // Com letra grande o nome não é cortado (H9).
                            maxLines: isLargeText(context) ? null : 2,
                            overflow: isLargeText(context) ? TextOverflow.visible : TextOverflow.ellipsis,
                            style: BipaText.title.copyWith(color: name == null ? colors.inkMuted : colors.ink),
                          ),
                          Text(widget.barcode, style: BipaText.barcode.copyWith(color: colors.inkMuted)),
                        ],
                      ),
                    ),
                    const SizedBox(width: BipaSpacing.s2),
                    IconButton.filledTonal(
                      tooltip: l10n.packageOtherProduct,
                      onPressed: _chooseProduct,
                      style: IconButton.styleFrom(
                        backgroundColor: colors.surfaceSunken,
                        foregroundColor: colors.ink,
                        fixedSize: const Size.square(44),
                      ),
                      icon: const Icon(Icons.swap_horiz_rounded),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: BipaSpacing.s4),
            PackageFields(
              brand: _brand,
              size: _size,
              unit: _unit,
              onUnitChanged: (unit) => setState(() {
                _unit = unit;
                _unitChosen = true;
              }),
              onSizeChanged: (_) => setState(() {}),
            ),
            if (price != null) ...[
              const SizedBox(height: BipaSpacing.s4),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: PriceTagHero(price: price, unitLine: unitPrice?.format()),
              ),
            ],
            if (_error case final error?) ...[const SizedBox(height: BipaSpacing.s3), ErrorLine(error)],
            const SizedBox(height: BipaSpacing.s4),
            FilledButton(
              // Sem produto, "Salvar" diz o que falta e abre a escolha, em vez
              // de ficar apagado sem explicação.
              onPressed: _saving
                  ? null
                  : name == null
                  ? _askForProduct
                  : _save,
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }
}
