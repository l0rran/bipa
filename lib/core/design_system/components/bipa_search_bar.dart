import 'package:bipa/core/design_system/bipa_metrics.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/design_system/bipa_typography.dart';
import 'package:flutter/material.dart';

/// Busca no topo das telas, com o botão de bipar dentro: em vez de digitar o
/// nome, aponte a câmera para o código de barras.
class BipaSearchBar extends StatelessWidget {
  const BipaSearchBar({
    required this.hint,
    required this.onChanged,
    this.onScan,
    this.scanLabel,
    this.controller,
    super.key,
  });

  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback? onScan;
  final String? scanLabel;
  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final onScan = this.onScan;
    return Material(
      color: colors.surface,
      shape: const StadiumBorder(),
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            const SizedBox(width: BipaSpacing.s4),
            Icon(Icons.search_rounded, size: 22, color: colors.inkMuted),
            const SizedBox(width: BipaSpacing.s2),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                textInputAction: TextInputAction.search,
                style: BipaText.body.copyWith(fontSize: 16, color: colors.ink),
                decoration: InputDecoration.collapsed(
                  hintText: hint,
                  hintStyle: BipaText.body.copyWith(fontSize: 16, color: colors.inkMuted),
                ),
              ),
            ),
            if (onScan != null)
              Padding(
                padding: const EdgeInsets.all(6),
                child: IconButton(
                  onPressed: onScan,
                  tooltip: scanLabel,
                  style: IconButton.styleFrom(
                    backgroundColor: colors.surfaceSunken,
                    foregroundColor: colors.ink,
                    fixedSize: const Size.square(40),
                  ),
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                ),
              )
            else
              const SizedBox(width: BipaSpacing.s4),
          ],
        ),
      ),
    );
  }
}
