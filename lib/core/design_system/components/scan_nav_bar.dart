import 'dart:ui' show ImageFilter;

import 'package:bipa/core/design_system/bipa_metrics.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/design_system/bipa_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Um destino da barra de navegação.
class ScanNavDestination {
  const ScanNavDestination({required this.icon, required this.selectedIcon, required this.label});

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// Barra de navegação de vidro, flutuante, com o botão de bipar no centro em
/// amarelo. Os destinos se dividem metade de cada lado do botão.
///
/// Use com `Scaffold(extendBody: true)` para o conteúdo passar por trás.
class ScanNavBar extends StatelessWidget {
  const ScanNavBar({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    required this.onScan,
    required this.scanLabel,
    super.key,
  });

  final List<ScanNavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onScan;
  final String scanLabel;

  static const _barHeight = 72.0;
  static const _scanLift = 22.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final half = (destinations.length / 2).ceil();

    Widget destination(int index) => Expanded(
      child: _Destination(
        destination: destinations[index],
        selected: index == selectedIndex,
        onTap: () => onSelected(index),
      ),
    );

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      // O botão de bipar sobe 22 px acima da pílula. A caixa inclui essa parte,
      // porque o toque não passa dos limites do pai mesmo com Clip.none.
      child: SizedBox(
        height: _barHeight + _scanLift,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: _scanLift,
              bottom: 0,
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  shape: const StadiumBorder(),
                  shadows: [BoxShadow(color: colors.ink.withValues(alpha: 0.12), blurRadius: 24, offset: const Offset(0, 8))],
                ),
                child: ClipPath(
                  clipper: const ShapeBorderClipper(shape: StadiumBorder()),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: ColoredBox(
                      color: colors.surfaceGlass,
                      child: Row(
                        children: [
                          for (var i = 0; i < half; i++) destination(i),
                          const SizedBox(width: 76),
                          for (var i = half; i < destinations.length; i++) destination(i),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(top: 0, child: _ScanButton(label: scanLabel, onPressed: onScan)),
          ],
        ),
      ),
    );
  }
}

class _Destination extends StatelessWidget {
  const _Destination({required this.destination, required this.selected, required this.onTap});

  final ScanNavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 36,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: BipaMotion.slow,
              curve: BipaMotion.spring,
              width: selected ? 52 : 32,
              height: 30,
              decoration: ShapeDecoration(
                shape: const StadiumBorder(),
                color: selected ? colors.brandSoft : Colors.transparent,
              ),
              child: Icon(
                selected ? destination.selectedIcon : destination.icon,
                size: 22,
                color: selected ? colors.ink : colors.inkMuted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              destination.label,
              maxLines: 1,
              style: BipaText.caption.copyWith(
                fontSize: 12,
                color: selected ? colors.ink : colors.inkMuted,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanButton extends StatelessWidget {
  const _ScanButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: colors.brand,
        shape: const CircleBorder(),
        elevation: 4,
        shadowColor: colors.ink.withValues(alpha: 0.4),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            HapticFeedback.lightImpact();
            onPressed();
          },
          child: SizedBox.square(
            dimension: 64,
            child: Icon(Icons.qr_code_scanner_rounded, size: 30, color: colors.onBrand),
          ),
        ),
      ),
    );
  }
}
