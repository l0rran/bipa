import 'dart:math' as math;

import 'package:bipa/core/design_system/bipa_metrics.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/design_system/bipa_typography.dart';
import 'package:bipa/core/design_system/text_scale.dart';
import 'package:flutter/material.dart';

/// A lista no Início (ListPreview do design system): quantos itens, o total
/// estimado, as miniaturas do que tem nela e uma ação só.
class ListPreviewCard extends StatelessWidget {
  const ListPreviewCard({
    required this.count,
    required this.countLabel,
    required this.thumbs,
    required this.actionLabel,
    required this.actionIcon,
    required this.onTap,
    required this.semanticLabel,
    this.estimate,
    this.extraCount = 0,
    super.key,
  });

  final int count;

  /// A palavra depois do número ("itens").
  final String countLabel;

  /// O total estimado, já formatado ("≈ R$ 84,30").
  final String? estimate;

  /// Até três miniaturas, já recortadas em círculo pelo componente.
  final List<Widget> thumbs;

  /// Quantos itens não couberam nas miniaturas ("+4").
  final int extraCount;
  final String actionLabel;
  final IconData actionIcon;
  final VoidCallback onTap;

  /// Resumo para leitores de tela: "Lista de compras: 7 itens, cerca de R$ 84,30".
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final estimate = this.estimate;
    final circles = [
      for (final thumb in thumbs.take(3)) thumb,
      if (extraCount > 0)
        Center(child: Text('+$extraCount', style: BipaText.label.copyWith(fontSize: 13, color: colors.ink))),
    ];

    // excludeSemantics descarta a ação do InkWell: ela vai no próprio Semantics.
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(BipaRadius.lg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(BipaSpacing.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text.rich(
                            TextSpan(
                              text: '$count',
                              style: BipaText.headline.copyWith(fontSize: 26, height: 30 / 26, color: colors.ink),
                              children: [
                                TextSpan(
                                  text: ' $countLabel',
                                  style: BipaText.number.copyWith(fontSize: 15, color: colors.inkMuted),
                                ),
                              ],
                            ),
                          ),
                          if (estimate != null)
                            Text(
                              estimate,
                              style: BipaText.label.copyWith(fontWeight: FontWeight.w600, color: colors.inkMuted),
                            ),
                        ],
                      ),
                    ),
                    for (final (index, circle) in circles.indexed)
                      Transform.translate(
                        // Sobrepostas, como no protótipo: cada uma avança 10 px sobre a anterior.
                        offset: Offset(-10.0 * (circles.length - 1 - index), 0),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: colors.surfaceSunken,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colors.surface,
                              width: 3,
                              strokeAlign: BorderSide.strokeAlignOutside,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  height: 48,
                  decoration: ShapeDecoration(color: colors.brand, shape: const StadiumBorder()),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(actionIcon, size: 18, color: colors.onBrand),
                      const SizedBox(width: BipaSpacing.s2),
                      Text(actionLabel, style: BipaText.label.copyWith(fontSize: 15, color: colors.onBrand)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Progresso da compra: o total estimado à esquerda, "3 de 7" à direita e a
/// barra embaixo.
class ShoppingProgress extends StatelessWidget {
  const ShoppingProgress({required this.label, required this.value, this.leading, super.key});

  /// "3 de 7".
  final String label;

  /// De 0 a 1.
  final double value;

  /// Texto à esquerda, como o total estimado.
  final String? leading;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final leading = this.leading;
    final small = BipaText.label.copyWith(fontSize: 13, fontWeight: FontWeight.w600, color: colors.inkMuted);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (leading != null) Expanded(child: Text(leading, style: small)) else const Spacer(),
            Text(label, style: small.copyWith(color: colors.ink, fontFeatures: const [FontFeature.tabularFigures()])),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(BipaRadius.pill),
          child: SizedBox(
            height: 8,
            child: Stack(
              children: [
                Positioned.fill(child: ColoredBox(color: colors.surfaceSunken)),
                TweenAnimationBuilder<double>(
                  tween: Tween(end: value.clamp(0.0, 1.0)),
                  duration: BipaMotion.slow,
                  curve: BipaMotion.spring,
                  builder: (context, fraction, _) => FractionallySizedBox(
                    alignment: AlignmentDirectional.centerStart,
                    heightFactor: 1,
                    // A mola passa um pouco do alvo: o fim fica entre 0 e 1.
                    widthFactor: fraction.clamp(0.0, 1.0),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.brand,
                        borderRadius: BorderRadius.circular(BipaRadius.pill),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Bloco dos itens de sempre: um toque põe ou tira da lista.
class QuickTile extends StatelessWidget {
  const QuickTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.size = 76,
    super.key,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double size;

  static const _padding = BipaSpacing.s2;
  static const _iconSize = 28.0;
  static const _gap = 6.0;

  /// O lado do bloco: [size], ou mais quando a letra grande não cabe nele. A
  /// lista horizontal usa o mesmo valor para a altura.
  static double sideFor(BuildContext context, {double size = 76}) => math.max(
    size,
    // 2 de folga para o arredondamento do texto.
    _padding * 2 + _iconSize + _gap + BipaText.caption.scaledLineHeight(context) + 2,
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final foreground = selected ? colors.brandText : colors.ink;

    return Semantics(
      button: true,
      toggled: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: SizedBox.square(
        dimension: sideFor(context, size: size),
        child: Material(
          color: selected ? colors.brandSoft : colors.surface,
          borderRadius: BorderRadius.circular(BipaRadius.md),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(_padding),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, size: _iconSize, color: selected ? colors.brandText : colors.inkMuted),
                        const SizedBox(height: _gap),
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: BipaText.caption.copyWith(letterSpacing: 0, color: foreground),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  right: 6,
                  top: 6,
                  child: AnimatedScale(
                    scale: selected ? 1 : 0,
                    duration: BipaMotion.base,
                    curve: BipaMotion.spring,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(color: colors.brand, shape: BoxShape.circle),
                      child: Icon(Icons.check_rounded, size: 12, color: colors.onBrand),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Cartão de uma seção do mercado na lista, com o nome e quantos já foram
/// comprados ("1/2").
class ShoppingSectionCard extends StatelessWidget {
  const ShoppingSectionCard({required this.title, required this.progress, required this.children, super.key});

  final String title;
  final String progress;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = BipaText.label.copyWith(fontSize: 13, color: colors.inkMuted);

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(BipaRadius.lg),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: BipaSpacing.s1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(BipaSpacing.s4, 10, BipaSpacing.s4, BipaSpacing.s1),
              child: Row(
                children: [
                  Expanded(child: Semantics(header: true, child: Text(title, style: style))),
                  Text(progress, style: style.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
                ],
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Item da lista: a caixa de marcar, a quantidade (quando é mais de uma), o
/// nome e o preço esperado. Comprado, o nome fica riscado e a linha esmaece.
class ShoppingListRow extends StatelessWidget {
  const ShoppingListRow({
    required this.name,
    required this.checked,
    required this.onChanged,
    this.price,
    this.quantity,
    this.quantitySpoken,
    this.onLongPress,
    super.key,
  });

  final String name;
  final bool checked;
  final ValueChanged<bool> onChanged;

  /// O preço esperado, já formatado ("≈ 7,90").
  final String? price;

  /// "3×", em cinza antes do nome; `null` para uma embalagem só.
  final String? quantity;

  /// A quantidade para o leitor de tela ("3 embalagens").
  final String? quantitySpoken;

  /// O toque longo muda a quantidade.
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final price = this.price;
    final quantity = this.quantity;

    return Semantics(
      button: true,
      checked: checked,
      label: [name, ?(quantitySpoken ?? quantity), ?price].join(', '),
      excludeSemantics: true,
      onTap: () => onChanged(!checked),
      child: InkWell(
        onTap: () => onChanged(!checked),
        onLongPress: onLongPress,
        child: AnimatedOpacity(
          opacity: checked ? 0.5 : 1,
          duration: BipaMotion.base,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: BipaSpacing.s4, vertical: BipaSpacing.s2),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: BipaMotion.base,
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: checked ? colors.ink : null,
                      borderRadius: BorderRadius.circular(BipaRadius.sm),
                      border: checked ? null : Border.all(color: colors.line, width: 2),
                    ),
                    child: checked ? Icon(Icons.check_rounded, size: 18, color: colors.surface) : null,
                  ),
                  const SizedBox(width: BipaSpacing.s3),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          if (quantity != null)
                            TextSpan(
                              text: '$quantity ',
                              style: TextStyle(
                                color: colors.inkMuted,
                                fontWeight: FontWeight.w600,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          TextSpan(text: name),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: BipaText.bodyLarge.copyWith(
                        fontSize: 15,
                        height: 20 / 15,
                        color: colors.ink,
                        decoration: checked ? TextDecoration.lineThrough : null,
                        decorationColor: colors.ink,
                      ),
                    ),
                  ),
                  if (price != null) ...[
                    const SizedBox(width: BipaSpacing.s3),
                    Text(
                      price,
                      style: BipaText.label.copyWith(
                        fontSize: 13,
                        color: colors.inkMuted,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A compra em andamento (ShoppingBar do design system): fica acima da
/// navegação com o progresso da lista e o total, e "Continuar" volta à lista.
class ShoppingBar extends StatelessWidget {
  const ShoppingBar({
    required this.title,
    required this.actionLabel,
    required this.progress,
    required this.onTap,
    required this.semanticLabel,
    this.subtitle,
    super.key,
  });

  /// "3 de 7 itens".
  final String title;

  /// O total e o mercado: "R$ 32,10 · Atacarejo Vila Nova".
  final String? subtitle;
  final String actionLabel;

  /// De 0 a 1.
  final double progress;
  final VoidCallback onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final subtitle = this.subtitle;

    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      onTap: onTap,
      child: TweenAnimationBuilder<double>(
        // Entra subindo com mola.
        tween: Tween(begin: 0, end: 1),
        duration: BipaMotion.slow,
        curve: BipaMotion.spring,
        builder: (context, t, child) => Transform.translate(offset: Offset(0, 24 * (1 - t)), child: child),
        child: Material(
          color: colors.brand,
          shape: const StadiumBorder(),
          elevation: 6,
          shadowColor: colors.ink.withValues(alpha: 0.3),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            // Pelo menos 60; com letra grande, cresce em vez de cortar.
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 60),
              child: Stack(
                // O conteúdo fica centrado na altura da barra.
                alignment: AlignmentDirectional.centerStart,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, BipaSpacing.s2, BipaSpacing.s2, BipaSpacing.s2),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: colors.onBrand.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.shopping_cart_outlined, size: 20, color: colors.onBrand),
                        ),
                        const SizedBox(width: BipaSpacing.s3),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: BipaText.number.copyWith(fontSize: 16, color: colors.onBrand),
                              ),
                              if (subtitle != null)
                                Text(
                                  subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: BipaText.label.copyWith(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: colors.onBrand.withValues(alpha: 0.75),
                                    fontFeatures: const [FontFeature.tabularFigures()],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: BipaSpacing.s2),
                        Container(
                          height: 44,
                          padding: const EdgeInsets.only(left: BipaSpacing.s4, right: 14),
                          decoration: ShapeDecoration(color: colors.ink, shape: const StadiumBorder()),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(actionLabel, style: BipaText.label.copyWith(color: colors.surface)),
                              const SizedBox(width: BipaSpacing.s1),
                              Icon(Icons.chevron_right_rounded, size: 18, color: colors.surface),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // O fio de progresso na base da barra.
                  Positioned(
                    left: 24,
                    right: 24,
                    bottom: 6,
                    height: 3,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ColoredBox(color: colors.onBrand.withValues(alpha: 0.14)),
                          TweenAnimationBuilder<double>(
                            tween: Tween(end: progress.clamp(0.0, 1.0)),
                            duration: BipaMotion.slow,
                            curve: BipaMotion.spring,
                            builder: (context, fraction, _) => FractionallySizedBox(
                              alignment: AlignmentDirectional.centerStart,
                              widthFactor: fraction.clamp(0.0, 1.0),
                              child: ColoredBox(color: colors.ink),
                            ),
                          ),
                        ],
                      ),
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
