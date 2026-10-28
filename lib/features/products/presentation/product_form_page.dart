import 'package:bipa/core/di/core_providers.dart';
import 'package:bipa/core/errors/domain_exception.dart';
import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/core/l10n/domain_error_text.dart';
import 'package:bipa/core/navigation/routes.dart';
import 'package:bipa/core/widgets/messages.dart';
import 'package:bipa/features/products/domain/gtin.dart';
import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/products/domain/product_package.dart';
import 'package:bipa/features/products/domain/product_repository.dart';
import 'package:bipa/features/products/domain/scale_label.dart';
import 'package:bipa/features/products/presentation/measure_unit_label.dart';
import 'package:bipa/features/products/presentation/products_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Valores iniciais para o cadastro de um produto novo.
@immutable
class ProductFormArgs {
  const ProductFormArgs({this.barcode, this.name});

  final String? barcode;
  final String? name;
}

/// Cadastro e edição de produto. Ao salvar, devolve o [Product] via `pop`.
///
/// Marca, código e tamanho são da embalagem (ADR 0013): no cadastro, criam
/// a primeira embalagem quando algum deles é preenchido. Na edição, o
/// formulário muda só o nome e a unidade do produto; cada embalagem tem a
/// própria edição, na tela do produto (G1).
class ProductFormPage extends ConsumerStatefulWidget {
  const ProductFormPage({this.productId, this.args = const ProductFormArgs(), super.key});

  /// Quando informado, edita o produto existente.
  final String? productId;
  final ProductFormArgs args;

  @override
  ConsumerState<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends ConsumerState<ProductFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _brand = TextEditingController();
  final _barcode = TextEditingController();
  final _packageSize = TextEditingController();
  var _unit = MeasureUnit.unit;
  Product? _original;
  var _loading = false;
  var _saving = false;

  bool get _isEditing => widget.productId != null;

  @override
  void initState() {
    super.initState();
    _barcode.text = widget.args.barcode ?? '';
    _name.text = widget.args.name ?? '';

    final productId = widget.productId;
    if (productId != null) {
      _loading = true;
      _load(productId);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _brand.dispose();
    _barcode.dispose();
    _packageSize.dispose();
    super.dispose();
  }

  Future<void> _load(String id) async {
    final repository = ref.read(productRepositoryProvider);
    final product = await repository.findById(id);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (product == null) return;
      _original = product;
      _name.text = product.name;
      _unit = product.unit;
    });
  }

  Future<void> _scanBarcode() async {
    final code = await context.push<String>(Routes.scanner);
    if (code != null && mounted) setState(() => _barcode.text = code);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final now = ref.read(clockProvider)();
    final ids = ref.read(idGeneratorProvider);
    final repository = ref.read(productRepositoryProvider);
    final original = _original;
    final product = Product(
      id: original?.id ?? ids.newId(),
      name: _name.text.trim(),
      unit: _unit,
      // A foto não é editada neste formulário: mantém a que já existe.
      photoPath: original?.photoPath,
      createdAt: original?.createdAt ?? now,
      updatedAt: now,
    );
    final brand = _nullIfBlank(_brand.text);
    final barcode = _nullIfBlank(_barcode.text);
    final size = _parseSize(_packageSize.text);
    // Só o cadastro cria a embalagem; a edição não mexe em nenhuma.
    final package = _isEditing || (brand == null && barcode == null && size == null)
        ? null
        : ProductPackage(
            id: ids.newId(),
            productId: product.id,
            brand: brand,
            barcode: barcode,
            size: size,
            unit: _unit,
            createdAt: now,
            updatedAt: now,
          );

    try {
      // O código é conferido antes de gravar o produto: um código repetido
      // não deixa um produto sem embalagem para trás.
      if (package != null && barcode != null) {
        final owner = await repository.findPackageByBarcode(barcode);
        if (owner != null) {
          final ownerProduct = await repository.findById(owner.productId);
          throw DuplicateBarcodeException(barcode: barcode, productName: ownerProduct?.name ?? barcode);
        }
      }
      await repository.save(product);
      if (package != null) await repository.savePackage(package);
      if (mounted) context.pop(product);
    } on DomainException catch (error) {
      if (mounted) context.showMessage(domainErrorText(AppLocalizations.of(context), error));
    } on Exception {
      if (mounted) context.showMessage(AppLocalizations.of(context).productSaveFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  static String? _nullIfBlank(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static double? _parseSize(String value) => double.tryParse(value.trim().replaceAll(',', '.'));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? l10n.productEditTitle : l10n.productsNew)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _name,
                    autofocus: !_isEditing && _name.text.isEmpty,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(labelText: l10n.formNameRequired),
                    validator: (value) => (value == null || value.trim().isEmpty) ? l10n.productNameMissing : null,
                  ),
                  if (!_isEditing) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _brand,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(labelText: l10n.packageBrand),
                    ),
                    const SizedBox(height: 16),
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
                      validator: (value) {
                        final code = value?.trim() ?? '';
                        if (ScaleLabel.isScaleCode(code)) return l10n.barcodeScale;
                        return code.isEmpty || Gtin.isValid(code) ? null : l10n.barcodeInvalid;
                      },
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!_isEditing) ...[
                        Expanded(
                          child: TextFormField(
                            controller: _packageSize,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: l10n.productPackageSize,
                              helperText: l10n.productPackageSizeHint,
                            ),
                            validator: (value) {
                              final text = value?.trim() ?? '';
                              if (text.isEmpty) return null;
                              final size = _parseSize(text);
                              return size == null || size <= 0 ? l10n.formInvalidValue : null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: DropdownMenu<MeasureUnit>(
                          initialSelection: _unit,
                          label: Text(l10n.packageUnit),
                          expandedInsets: EdgeInsets.zero,
                          dropdownMenuEntries: [
                            for (final unit in MeasureUnit.values)
                              DropdownMenuEntry(
                                value: unit,
                                label: l10n.measureUnitOption(unit.localizedLabel(l10n), unit.symbol),
                              ),
                          ],
                          onSelected: (unit) {
                            if (unit != null) setState(() => _unit = unit);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.check),
                    label: Text(l10n.save),
                  ),
                ],
              ),
            ),
    );
  }
}
