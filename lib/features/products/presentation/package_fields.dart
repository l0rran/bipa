import 'package:bipa/core/design_system/bipa_metrics.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/design_system/bipa_typography.dart';
import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:flutter/material.dart';

/// Os campos de uma embalagem, iguais na "Embalagem nova" e em "Editar
/// embalagem": a marca e, ao lado, o tamanho com a unidade dentro do campo
/// ("5 kg"). Os campos ficam em `surface-sunken` para aparecerem sobre a
/// folha clara.
class PackageFields extends StatelessWidget {
  const PackageFields({
    required this.brand,
    required this.size,
    required this.unit,
    required this.onUnitChanged,
    this.onSizeChanged,
    this.sizeValidator,
    super.key,
  });

  final TextEditingController brand;
  final TextEditingController size;
  final MeasureUnit unit;
  final ValueChanged<MeasureUnit> onUnitChanged;
  final ValueChanged<String>? onSizeChanged;

  /// Validação do tamanho dentro de um [Form]; sem [Form], não roda.
  final FormFieldValidator<String>? sizeValidator;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final field = InputDecoration(fillColor: colors.surfaceSunken);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 7,
          child: TextFormField(
            controller: brand,
            textCapitalization: TextCapitalization.words,
            decoration: field.copyWith(labelText: l10n.packageBrand),
          ),
        ),
        const SizedBox(width: BipaSpacing.s3),
        Expanded(
          flex: 5,
          child: TextFormField(
            controller: size,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: sizeValidator,
            decoration: field.copyWith(
              labelText: l10n.packageSize,
              suffixIcon: Semantics(
                label: l10n.packageUnit,
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<MeasureUnit>(
                    value: unit,
                    borderRadius: BorderRadius.circular(BipaRadius.md),
                    style: BipaText.label.copyWith(color: colors.inkMuted),
                    items: [
                      for (final unit in MeasureUnit.values) DropdownMenuItem(value: unit, child: Text(unit.symbol)),
                    ],
                    onChanged: (unit) {
                      if (unit != null) onUnitChanged(unit);
                    },
                  ),
                ),
              ),
            ),
            onChanged: onSizeChanged,
          ),
        ),
      ],
    );
  }
}
