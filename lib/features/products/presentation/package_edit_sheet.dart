import 'package:bipa/core/design_system/bipa_metrics.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/design_system/bipa_typography.dart';
import 'package:bipa/core/design_system/components/bipa_toast.dart';
import 'package:bipa/core/di/core_providers.dart';
import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/features/products/domain/product_package.dart';
import 'package:bipa/features/products/presentation/package_fields.dart';
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
      showBipaToast(messenger, l10n.packageSaveFailed);
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
              // O código na fonte dos códigos (JetBrains Mono), como na
              // "Embalagem nova".
              if (barcode != null) Text(barcode, style: BipaText.barcode.copyWith(color: colors.inkMuted)),
              const SizedBox(height: BipaSpacing.s4),
              // Os mesmos campos da "Embalagem nova", com a unidade dentro do
              // tamanho.
              PackageFields(
                brand: _brand,
                size: _size,
                unit: _unit,
                onUnitChanged: (unit) => setState(() => _unit = unit),
                sizeValidator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return null;
                  final size = _parseSize(text);
                  return size == null || size <= 0 ? l10n.packageSizeInvalid : null;
                },
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
