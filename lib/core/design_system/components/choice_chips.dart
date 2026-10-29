import 'package:bipa/core/design_system/bipa_metrics.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/design_system/bipa_typography.dart';
import 'package:bipa/core/design_system/components/tap_target.dart';
import 'package:flutter/material.dart';

/// Uma opção dos [ChoiceChips].
class ChoiceOption<T> {
  const ChoiceOption({required this.value, required this.label, required this.icon});

  final T value;
  final String label;
  final IconData icon;
}

/// Os chips compactos do FilterChips usados como escolha (protótipo "Arrumar
/// o que entrou" e "Guardar em casa, escolher o local"): uma escolha só, sem
/// contagem e sem "Tudo". O escolhido fica cheio em `ink`; os outros, em
/// `surface-sunken`, para aparecerem sobre a folha clara.
///
/// Por padrão, uma fileira que rola para o lado, dentro de outro controle
/// (a linha aberta). Com [wrap], os chips quebram a linha, ficam maiores e
/// o escolhido troca o ícone pelo visto: é a forma da folha que só serve
/// para escolher.
///
/// Para o leitor de tela, é um grupo de opções exclusivas com o nome
/// [semanticsLabel], e cada chip diz se está marcado.
class ChoiceChips<T> extends StatelessWidget {
  const ChoiceChips({
    required this.options,
    required this.selected,
    required this.onSelected,
    required this.semanticsLabel,
    this.wrap = false,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  final List<ChoiceOption<T>> options;
  final T? selected;
  final ValueChanged<T> onSelected;

  /// O nome do grupo: "Onde fica o Leite integral 1 L".
  final String semanticsLabel;

  /// Quebra a linha em vez de rolar para o lado.
  final bool wrap;

  /// A folga das pontas da fileira que rola, para ela poder ir até a borda
  /// da tela e o primeiro chip continuar alinhado ao conteúdo.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final chips = [
      for (final option in options)
        _Chip(option: option, selected: option.value == selected, large: wrap, onTap: () => onSelected(option.value)),
    ];
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: semanticsLabel,
      child: wrap
          ? Padding(
              padding: padding,
              child: Wrap(spacing: BipaSpacing.s2, children: chips),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: padding,
              clipBehavior: Clip.none,
              child: Row(
                children: [
                  for (final (index, chip) in chips.indexed) ...[
                    if (index > 0) const SizedBox(width: BipaSpacing.s2),
                    chip,
                  ],
                ],
              ),
            ),
    );
  }
}

class _Chip<T> extends StatelessWidget {
  const _Chip({required this.option, required this.selected, required this.large, required this.onTap});

  final ChoiceOption<T> option;
  final bool selected;
  final bool large;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final foreground = selected ? colors.ground : colors.ink;
    final iconSize = large ? 18.0 : 16.0;
    return Semantics(
      button: true,
      inMutuallyExclusiveGroup: true,
      checked: selected,
      label: option.label,
      excludeSemantics: true,
      onTap: onTap,
      // O chip tem 36 (ou 44) de altura; a área de toque, 48.
      child: TapTarget(
        onTap: onTap,
        child: Material(
          color: selected ? colors.ink : colors.surfaceSunken,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Container(
              // Mínima, não fixa: com letra grande, o chip cresce em vez de cortar (H3).
              constraints: BoxConstraints(minHeight: large ? 44 : 36),
              padding: EdgeInsets.symmetric(horizontal: large ? BipaSpacing.s4 : 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(large && selected ? Icons.check_rounded : option.icon, size: iconSize, color: foreground),
                  const SizedBox(width: 6),
                  Text(
                    option.label,
                    style: BipaText.label.copyWith(
                      fontSize: large ? 15 : 14,
                      fontWeight: FontWeight.w600,
                      color: foreground,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
