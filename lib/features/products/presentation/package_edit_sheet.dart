import 'package:bipa/core/design_system/bipa_metrics.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/design_system/bipa_typography.dart';
import 'package:bipa/core/di/core_providers.dart';
import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:bipa/features/products/domain/product_package.dart';
import 'package:bipa/features/products/presentation/measure_unit_label.dart';
import 'package:bipa/features/products/presentation/products_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Abre a edição de uma embalagem: marca, tamanho e unidade (G1). O código
/// de barras fica à vista, sem edição: é ele que identifica a embalagem.
/// Mudar o tamanho refaz o preço por kg de todo o histórico dela, que é o
/// que se quer quando o tamanho estava errado.
Future<void> showPackageEditSheet(BuildContext context, ProductPackage package) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => PackageEditSheet(package: package),
);

class PackageEditSheet extends ConsumerStatefulWidget {
  const PackageEditSheet({required this.package, super.key});

  final ProductPackage package;

  @override
  ConsumerState<PackageEditSheet> createState() => _PackageEditSheetState();
}

class _PackageEditSheetState extends ConsumerState<PackageEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _brand = TextEditingController(text: widget.package.brand ?? '');
  late final _size = TextEditingController(text: _formatSize(widget.package.size));
  late var _unit = widget.package.unit;
  var _saving = false;

  @override
  void dispose() {
    _brand.dispose();
    _size.dispose();
    super.dispose();
  }

  static String _formatSize(double? size) {
    if (size == null) return '';
    return size == size.truncateToDouble() ? size.toStringAsFixed(0) : '$size'.replaceAll('.', ',');
  }

  static double? _parseSize(String value) => double.tryParse(value.trim().replaceAll(',', '.'));

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);
    final repository = ref.read(productRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final now = ref.read(clockProvider)();
    final original = widget.package;
    final brand = _brand.text.trim();
    setState(() => _saving = true);
    try {
      await repository.savePackage(
        ProductPackage(
          id: original.id,
          productId: original.productId,
          barcode: original.barcode,
          brand: brand.isEmpty ? null : brand,
          size: _parseSize(_size.text),
          unit: _unit,
          createdAt: original.createdAt,
          updatedAt: now,
        ),
      );
      navigator.pop();
    } on Exception {
      messenger.showSnackBar(SnackBar(content: Text(l10n.packageSaveFailed)));
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final barcode = widget.package.barcode;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        BipaSpacing.s4,
        0,
        BipaSpacing.s4,
        BipaSpacing.s4 + MediaQuery.viewInsetsOf(context).bottom + MediaQuery.paddingOf(context).bottom,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(l10n.packageEditTitle, style: BipaText.headline.copyWith(fontSize: 22, color: colors.ink)),
              ),
              if (barcode != null)
                Text(barcode, style: BipaText.body.copyWith(color: colors.inkMuted, letterSpacing: 0.5)),
              const SizedBox(height: BipaSpacing.s4),
              TextFormField(
                controller: _brand,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(labelText: l10n.packageBrand),
              ),
              const SizedBox(height: BipaSpacing.s4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _size,
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
                  const SizedBox(width: BipaSpacing.s3),
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
              const SizedBox(height: BipaSpacing.s6),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                onPressed: _saving ? null : _save,
                child: Text(l10n.save),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
