import 'package:bipa/core/di/core_providers.dart';
import 'package:bipa/core/errors/domain_exception.dart';
import 'package:bipa/core/navigation/routes.dart';
import 'package:bipa/core/widgets/messages.dart';
import 'package:bipa/features/products/domain/gtin.dart';
import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:bipa/features/products/domain/product.dart';
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
    final product = await ref.read(productRepositoryProvider).findById(id);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (product == null) return;
      _original = product;
      _name.text = product.name;
      _brand.text = product.brand ?? '';
      _barcode.text = product.barcode ?? '';
      _unit = product.unit;
      final size = product.packageSize;
      _packageSize.text = size == null
          ? ''
          : (size == size.truncateToDouble() ? size.toStringAsFixed(0) : '$size'.replaceAll('.', ','));
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
    final original = _original;
    final product = Product(
      id: original?.id ?? ref.read(idGeneratorProvider).newId(),
      name: _name.text.trim(),
      brand: _nullIfBlank(_brand.text),
      barcode: _nullIfBlank(_barcode.text),
      unit: _unit,
      packageSize: _parseSize(_packageSize.text),
      // A foto não é editada neste formulário: mantém a que já existe.
      photoPath: original?.photoPath,
      createdAt: original?.createdAt ?? now,
      updatedAt: now,
    );

    try {
      await ref.read(productRepositoryProvider).save(product);
      if (mounted) context.pop(product);
    } on DomainException catch (error) {
      if (mounted) context.showMessage(error.message);
    } on Exception {
      if (mounted) context.showMessage('Não foi possível salvar o produto.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  static String? _nullIfBlank(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static double? _parseSize(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.'));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Editar produto' : 'Novo produto')),
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
                    decoration: const InputDecoration(labelText: 'Nome *'),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty) ? 'Informe o nome do produto' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _brand,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Marca'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _barcode,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Código de barras',
                      suffixIcon: IconButton(
                        tooltip: 'Ler com a câmera',
                        icon: const Icon(Icons.qr_code_scanner),
                        onPressed: _scanBarcode,
                      ),
                    ),
                    validator: (value) {
                      final code = value?.trim() ?? '';
                      return code.isEmpty || Gtin.isValid(code) ? null : 'Código de barras inválido';
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _packageSize,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Tamanho da embalagem',
                            helperText: 'Ex.: 395, 1,5, 12',
                          ),
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (text.isEmpty) return null;
                            final size = _parseSize(text);
                            return size == null || size <= 0 ? 'Valor inválido' : null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownMenu<MeasureUnit>(
                          initialSelection: _unit,
                          label: const Text('Unidade'),
                          expandedInsets: EdgeInsets.zero,
                          dropdownMenuEntries: [
                            for (final unit in MeasureUnit.values)
                              DropdownMenuEntry(value: unit, label: '${unit.label} (${unit.symbol})'),
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
                    label: const Text('Salvar'),
                  ),
                ],
              ),
            ),
    );
  }
}
