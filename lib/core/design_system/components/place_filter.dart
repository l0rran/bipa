import 'package:bipa/core/design_system/bipa_metrics.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/design_system/bipa_typography.dart';
import 'package:bipa/core/design_system/text_scale.dart';
import 'package:flutter/material.dart';

/// Uma opção do filtro de locais.
class PlaceOption<T> {
  const PlaceOption({required this.value, required this.label, required this.icon, required this.count});

  final T value;
  final String label;
  final IconData icon;
  final int count;
}

/// Locais como categorias (como as do iFood): arte grande com o nome embaixo
/// e a contagem num selo. Uma escolha só; o escolhido fica cheio em `ink`.
class PlaceFilter<T> extends StatelessWidget {
  const PlaceFilter({required this.options, required this.selected, required this.onSelected, super.key});

  final List<PlaceOption<T>> options;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // A arte, o espaço e o nome, que cresce com a letra; a folga de baixo
      // cabe a arte um pouco maior quando escolhida.
      height: 68 + 6 + BipaText.caption.scaledLineHeight(context) + 6,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: BipaSpacing.s4),
        clipBehavior: Clip.none,
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: BipaSpacing.s3),
        itemBuilder: (context, index) {
          final option = options[index];
          return _PlaceTile(option: option, selected: option.value == selected, onTap: () => onSelected(option.value));
        },
      ),
    );
  }
}

class _PlaceTile<T> extends StatelessWidget {
  const _PlaceTile({required this.option, required this.selected, required this.onTap});

  final PlaceOption<T> option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      label: '${option.label}, ${option.count}',
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 72,
          child: Column(
            children: [
              SizedBox.square(
                dimension: 68,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    AnimatedScale(
                      duration: BipaMotion.slow,
                      curve: BipaMotion.spring,
                      scale: selected ? 1.04 : 1,
                      child: AnimatedContainer(
                        duration: BipaMotion.base,
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: selected ? colors.ink : colors.surface,
                          borderRadius: BorderRadius.circular(BipaRadius.lg),
                        ),
                        child: Icon(option.icon, size: 30, color: selected ? colors.ground : colors.ink),
                      ),
                    ),
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        // Mínimas, não fixas: com letra grande, o número cabe (H3).
                        constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        alignment: Alignment.center,
                        decoration: ShapeDecoration(
                          shape: StadiumBorder(side: BorderSide(color: colors.ground, width: 2)),
                          color: colors.surfaceSunken,
                        ),
                        child: Text(
                          '${option.count}',
                          style: BipaText.caption.copyWith(fontSize: 11, color: colors.ink),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                option.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: BipaText.caption.copyWith(color: selected ? colors.ink : colors.inkMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
