import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:bipa/core/design_system/bipa_metrics.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/design_system/bipa_typography.dart';
import 'package:bipa/core/design_system/components/shrink_to_fit.dart';
import 'package:bipa/core/design_system/components/tap_target.dart';
import 'package:bipa/core/design_system/text_scale.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Bandeja do modo carrinho (ScanTray do design system): folha clara sobre a
/// câmera, com o cabeçalho "Carrinho", o total "Vou levar", os itens bipados
/// e a barra de ações embaixo.
class ScanTray extends StatelessWidget {
  const ScanTray({
    required this.title,
    required this.totalLabel,
    required this.items,
    required this.footer,
    this.countLabel,
    this.totalValue,
    this.totalNote,
    this.maxListHeight = 196,
    this.handleLabel,
    this.onHandleTap,
    this.expanded = false,
    super.key,
  });

  final String title;

  /// "4 de 7 da lista".
  final String? countLabel;

  /// "Vou levar".
  final String totalLabel;

  /// "R$ 54,88"; sem nenhum preço, o total não aparece.
  final String? totalValue;

  /// Uma ressalva sob o total: "sem preço de 2 itens".
  final String? totalNote;

  /// A alça expande ou recolhe a lista: o rótulo diz o que o toque faz.
  final String? handleLabel;
  final VoidCallback? onHandleTap;

  /// A lista está expandida: arrastar a alça para baixo recolhe, e para
  /// cima expande. O toque alterna.
  final bool expanded;
  final List<Widget> items;
  final Widget footer;

  /// A bandeja mostra os últimos itens e rola o resto, sem cobrir a câmera.
  final double maxListHeight;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final countLabel = this.countLabel;
    final totalValue = this.totalValue;
    final totalNote = this.totalNote;
    final onHandleTap = this.onHandleTap;
    final handle = Container(
      width: 36,
      height: 4,
      decoration: ShapeDecoration(color: colors.line, shape: const StadiumBorder()),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(BipaRadius.lg)),
        boxShadow: [BoxShadow(color: colors.ink.withValues(alpha: 0.18), blurRadius: 24, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(BipaSpacing.s3, BipaSpacing.s3, BipaSpacing.s3, BipaSpacing.s4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // A alça: tocar ou arrastar para cima mostra mais itens.
              if (onHandleTap == null)
                Center(child: handle)
              else
                Semantics(
                  button: true,
                  label: handleLabel,
                  excludeSemantics: true,
                  onTap: onHandleTap,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onHandleTap,
                    onVerticalDragEnd: (details) {
                      // Para cima a velocidade é negativa.
                      final velocity = details.primaryVelocity ?? 0;
                      if (velocity < -100 && !expanded || velocity > 100 && expanded) onHandleTap();
                    },
                    child: SizedBox(height: 24, child: Center(child: handle)),
                  ),
                ),
              const SizedBox(height: BipaSpacing.s2),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: BipaSpacing.s1),
                child: LayoutBuilder(
                  builder: (context, constraints) => Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Semantics(
                              header: true,
                              child: Text(
                                title,
                                style: BipaText.number.copyWith(fontSize: 18, height: 24 / 18, color: colors.ink),
                              ),
                            ),
                            if (countLabel != null)
                              Text(
                                countLabel,
                                style: BipaText.label.copyWith(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: colors.inkMuted,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (totalValue != null)
                        // O total ocupa no máximo 55% da linha: o valor encolhe
                        // e a ressalva quebra a linha com letra grande (H3).
                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.55),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                totalLabel.toUpperCase(),
                                textAlign: TextAlign.end,
                                style: BipaText.caption.copyWith(fontSize: 11, height: 14 / 11, color: colors.inkMuted),
                              ),
                              ShrinkToFit(
                                maxWidth: constraints.maxWidth * 0.55,
                                child: Text(
                                  totalValue,
                                  style: BipaText.price.copyWith(fontSize: 22, height: 26 / 22, color: colors.ink),
                                ),
                              ),
                              if (totalNote != null)
                                Text(
                                  totalNote,
                                  textAlign: TextAlign.end,
                                  style: BipaText.caption.copyWith(color: colors.inkMuted),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (items.isNotEmpty) ...[
                const SizedBox(height: BipaSpacing.s3),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxListHeight),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: BipaSpacing.s2),
                    itemBuilder: (context, index) => items[index],
                  ),
                ),
              ],
              const SizedBox(height: BipaSpacing.s3),
              footer,
            ],
          ),
        ),
      ),
    );
  }
}

/// Um item da bandeja: nome, preço numa mini etiqueta e o "levar".
class ScanTrayItem extends StatelessWidget {
  const ScanTrayItem({
    required this.name,
    required this.take,
    required this.takeLabel,
    required this.onTakeChanged,
    required this.onPriceTap,
    required this.priceTapLabel,
    this.price,
    this.priceEstimated = false,
    this.priceSemanticsLabel,
    this.justRead = false,
    this.onNameTap,
    this.nameTapLabel,
    super.key,
  });

  /// Nome do produto, já com a quantidade quando passa de um ("2× Café").
  final String name;

  /// "R$ 27,90"; `null` mostra um traço para digitar.
  final String? price;

  /// O preço é o do histórico, não o lido hoje: a etiqueta fica vazada (só o
  /// contorno), e a cheia fica para o preço confirmado. É o único sinal na
  /// tela; o leitor de tela ouve [priceSemanticsLabel].
  final bool priceEstimated;

  /// O que o leitor de tela diz do preço ("R$ 27,90, estimado"); sem ele,
  /// o próprio [price].
  final String? priceSemanticsLabel;

  /// Tocar no nome muda a quantidade.
  final VoidCallback? onNameTap;

  /// Rótulo acessível do nome: "Quantidade de Café".
  final String? nameTapLabel;
  final bool take;

  /// Rótulo acessível do interruptor: "Levar Café Pilão".
  final String takeLabel;
  final ValueChanged<bool> onTakeChanged;
  final VoidCallback onPriceTap;

  /// Rótulo acessível do preço: "Digitar o preço".
  final String priceTapLabel;

  /// O preço acabou de ser lido da etiqueta: um anel em volta da mini
  /// etiqueta, por um instante.
  final bool justRead;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final price = this.price;
    final dimmed = take ? 1.0 : 0.45;
    final onNameTap = this.onNameTap;
    // Com letra grande o nome ganha a linha inteira e não é cortado (H9).
    final large = isLargeText(context);
    final nameText = AnimatedOpacity(
      opacity: dimmed,
      duration: BipaMotion.base,
      child: Text(
        name,
        maxLines: large ? null : 2,
        overflow: large ? TextOverflow.visible : TextOverflow.ellipsis,
        style: BipaText.label.copyWith(fontWeight: FontWeight.w600, color: colors.ink),
      ),
    );
    // Preço confirmado: etiqueta cheia; estimado: só o contorno; sem preço:
    // o traço para digitar.
    final Color tagColor;
    final Color tagText;
    var tagBorder = BorderSide.none;
    if (price == null) {
      tagColor = colors.surfaceSunken;
      tagText = colors.inkMuted;
    } else if (priceEstimated) {
      tagColor = colors.surface;
      tagText = colors.ink;
      tagBorder = BorderSide(color: colors.price, width: 2);
    } else {
      tagColor = colors.price;
      tagText = colors.onPrice;
    }

    final nameWidget = onNameTap == null
        ? (large
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: BipaSpacing.s2),
                  child: nameText,
                )
              : nameText)
        : Semantics(
            button: true,
            label: nameTapLabel,
            hint: name,
            excludeSemantics: true,
            onTap: onNameTap,
            child: InkWell(
              onTap: onNameTap,
              borderRadius: BorderRadius.circular(BipaRadius.sm),
              // A área de toque tem a altura mínima de 48.
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Align(alignment: AlignmentDirectional.centerStart, child: nameText),
              ),
            ),
          );

    return LayoutBuilder(
      builder: (context, constraints) {
        final tagMaxWidth = constraints.maxWidth * 0.45;
        final priceTag = AnimatedOpacity(
          opacity: dimmed,
          duration: BipaMotion.base,
          child: Semantics(
            button: true,
            label: priceSemanticsLabel ?? price ?? priceTapLabel,
            excludeSemantics: true,
            onTap: onPriceTap,
            // A etiqueta é pequena, mas a área de toque tem 48 de altura.
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onPriceTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Center(
                  widthFactor: 1,
                  child: AnimatedContainer(
                    duration: BipaMotion.base,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(BipaRadius.sm),
                      boxShadow: [if (justRead) BoxShadow(color: colors.brandSoft, spreadRadius: 3)],
                    ),
                    child: Material(
                      color: tagColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(BipaRadius.sm),
                        side: tagBorder,
                      ),
                      child: InkWell(
                        onTap: onPriceTap,
                        borderRadius: BorderRadius.circular(BipaRadius.sm),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          // Preço não quebra a linha: com letra grande, encolhe
                          // até 45% da linha da bandeja (H3).
                          child: ShrinkToFit(
                            maxWidth: tagMaxWidth,
                            child: Text(
                              price ?? '—',
                              style: BipaText.number.copyWith(fontSize: 14, height: 18 / 14, color: tagText),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final toggle = BipaToggle(value: take, onChanged: onTakeChanged, semanticLabel: takeLabel);
        return Container(
          padding: const EdgeInsets.fromLTRB(BipaSpacing.s3, BipaSpacing.s1, BipaSpacing.s1, BipaSpacing.s1),
          decoration: BoxDecoration(color: colors.ground, borderRadius: BorderRadius.circular(BipaRadius.md)),
          child: large
              // Letra grande: o nome inteiro em cima, e o preço e o
              // interruptor embaixo (H9).
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    nameWidget,
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        priceTag,
                        const SizedBox(width: BipaSpacing.s3),
                        toggle,
                      ],
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: nameWidget),
                    const SizedBox(width: BipaSpacing.s3),
                    priceTag,
                    const SizedBox(width: BipaSpacing.s3),
                    toggle,
                  ],
                ),
        );
      },
    );
  }
}

/// Interruptor do design system: trilho `line` desligado e `ink` ligado.
class BipaToggle extends StatelessWidget {
  const BipaToggle({required this.value, required this.onChanged, required this.semanticLabel, super.key});

  final bool value;
  final ValueChanged<bool> onChanged;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      toggled: value,
      label: semanticLabel,
      excludeSemantics: true,
      onTap: () => onChanged(!value),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        // O trilho tem 44×28; a área de toque, 48×48.
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          child: AnimatedContainer(
            duration: BipaMotion.base,
            width: 44,
            height: 28,
            padding: const EdgeInsets.all(3),
            alignment: value ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
            decoration: ShapeDecoration(color: value ? colors.ink : colors.line, shape: const StadiumBorder()),
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: colors.surface,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: colors.ink.withValues(alpha: 0.25), blurRadius: 3, offset: const Offset(0, 1)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Moldura do visor (ScanFrame): quatro cantos e o laser coral varrendo.
/// [locked] encolhe a moldura e esconde o laser quando um código é lido.
class ScanViewfinder extends StatefulWidget {
  const ScanViewfinder({this.locked = false, super.key});

  final bool locked;

  @override
  State<ScanViewfinder> createState() => _ScanViewfinderState();
}

class _ScanViewfinderState extends State<ScanViewfinder> with SingleTickerProviderStateMixin {
  late final _sweep = AnimationController(vsync: this, duration: const Duration(seconds: 2));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Com "remover animações" ligado no aparelho, o laser fica parado no meio.
    if (MediaQuery.disableAnimationsOf(context)) {
      _sweep
        ..stop()
        ..value = 0.5;
    } else if (!_sweep.isAnimating) {
      _sweep.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final locked = widget.locked;
    final cornerColor = locked ? colors.positiveSoft : colors.onCamera;

    return AnimatedContainer(
      duration: BipaMotion.slow,
      curve: BipaMotion.spring,
      width: locked ? 220 : 260,
      height: locked ? 96 : 150,
      child: Stack(
        children: [
          for (final corner in _corners)
            Align(
              alignment: corner,
              child: _Corner(alignment: corner, color: cornerColor),
            ),
          if (!locked)
            AnimatedBuilder(
              animation: _sweep,
              builder: (context, _) => Align(
                alignment: Alignment(0, Curves.easeInOut.transform(_sweep.value) * 1.6 - 0.8),
                child: Container(
                  height: 3,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: ShapeDecoration(
                    color: colors.alert,
                    shape: const StadiumBorder(),
                    shadows: [BoxShadow(color: colors.alert, blurRadius: 12, spreadRadius: 2)],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

const _corners = [Alignment.topLeft, Alignment.topRight, Alignment.bottomLeft, Alignment.bottomRight];

class _Corner extends StatelessWidget {
  const _Corner({required this.alignment, required this.color});

  final Alignment alignment;
  final Color color;

  @override
  Widget build(BuildContext context) {
    const radius = Radius.circular(14);
    final side = BorderSide(color: color, width: 4);
    final top = alignment.y < 0;
    final left = alignment.x < 0;
    return AnimatedContainer(
      duration: BipaMotion.base,
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        border: Border(
          top: top ? side : BorderSide.none,
          bottom: top ? BorderSide.none : side,
          left: left ? side : BorderSide.none,
          right: left ? BorderSide.none : side,
        ),
        borderRadius: BorderRadius.only(
          topLeft: top && left ? radius : Radius.zero,
          topRight: top && !left ? radius : Radius.zero,
          bottomLeft: !top && left ? radius : Radius.zero,
          bottomRight: !top && !left ? radius : Radius.zero,
        ),
      ),
    );
  }
}

/// Botão redondo de vidro escuro, para usar sobre a câmera.
class CameraGlassButton extends StatelessWidget {
  const CameraGlassButton({required this.icon, required this.label, required this.onPressed, super.key});

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Material(
            color: colors.camera.withValues(alpha: 0.55),
            child: InkWell(
              onTap: onPressed,
              child: SizedBox.square(dimension: 48, child: Icon(icon, size: 22, color: colors.onCamera)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Chip de vidro escuro sobre a câmera: o mercado atual, por exemplo.
class CameraGlassChip extends StatelessWidget {
  const CameraGlassChip({required this.icon, required this.label, required this.onTap, super.key});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      // O chip tem 40 de altura; a área de toque, 48.
      child: TapTarget(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(BipaRadius.pill),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Material(
              color: colors.camera.withValues(alpha: 0.55),
              child: InkWell(
                onTap: onTap,
                child: Container(
                  // Pelo menos 40; com letra grande, o chip cresce em vez de cortar (H3).
                  constraints: const BoxConstraints(minHeight: 40),
                  padding: const EdgeInsets.only(left: BipaSpacing.s2, right: BipaSpacing.s3),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 18, color: colors.onCamera),
                      const SizedBox(width: BipaSpacing.s2),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: BipaText.label.copyWith(color: colors.onCamera),
                        ),
                      ),
                      const SizedBox(width: BipaSpacing.s1),
                      Icon(Icons.expand_more_rounded, size: 16, color: colors.onCamera),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Aviso da leitura ao vivo sobre a câmera (protótipo "Modo carrinho: preço
/// lido"): o preço da etiqueta em destaque e, ao lado, o item que o recebeu
/// ou o que falta fazer. O leitor de tela anuncia a mudança. Só é tocável com
/// [onTap] (protótipo "Modo carrinho: granel sem código").
class LiveReadChip extends StatelessWidget {
  const LiveReadChip({
    required this.icon,
    required this.detail,
    this.price,
    this.countdown,
    this.onTap,
    this.actionLabel,
    super.key,
  });

  final IconData icon;

  /// Quanto tempo o aviso espera: um anel em volta do ícone esvazia nesse
  /// tempo (o preço que espera o produto).
  final Duration? countdown;

  /// "R$ 27,90" ou "+1"; sem ele, o aviso é só o texto.
  final String? price;

  /// O nome do item ou "bipe o produto".
  final String detail;

  /// Com ele, o aviso vira botão (com a seta): o granel sem código, que não
  /// tem o que bipar, escolhe o produto por aqui (ADR 0018).
  final VoidCallback? onTap;

  /// No lugar da seta, quando o toque não leva a outro lugar e precisa dizer
  /// o que faz ("Desfazer").
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final onTap = this.onTap;
    final chip = Semantics(
      liveRegion: true,
      button: onTap != null,
      onTap: onTap,
      label: [?price, detail, ?(onTap == null ? null : actionLabel)].join(', '),
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(BipaRadius.pill),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            // Pelo menos 40; com letra grande, o aviso cresce em vez de cortar (H3).
            constraints: const BoxConstraints(minHeight: 40),
            color: colors.camera.withValues(alpha: 0.55),
            padding: const EdgeInsets.only(left: BipaSpacing.s3, right: BipaSpacing.s4),
            // O preço e a ação não quebram a linha: com letra grande, encolhem
            // até um teto, e o texto fica com o resto (H3).
            child: LayoutBuilder(
              builder: (context, constraints) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (countdown case final countdown?)
                    _CountdownRing(
                      duration: countdown,
                      color: colors.onCamera,
                      child: Icon(icon, size: 14, color: colors.onCamera),
                    )
                  else
                    Icon(icon, size: 18, color: colors.onCamera),
                  const SizedBox(width: BipaSpacing.s2),
                  if (price case final price?) ...[
                    ShrinkToFit(
                      maxWidth: constraints.maxWidth * 0.5,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        price,
                        style: BipaText.number.copyWith(fontSize: 16, height: 20 / 16, color: colors.onCamera),
                      ),
                    ),
                    const SizedBox(width: BipaSpacing.s2),
                  ],
                  Flexible(
                    child: Text(
                      detail,
                      maxLines: MediaQuery.textScalerOf(context).scale(1) > 1.3 ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: BipaText.caption.copyWith(color: colors.onCamera.withValues(alpha: 0.75)),
                    ),
                  ),
                  if (onTap != null)
                    if (actionLabel case final action?) ...[
                      const SizedBox(width: BipaSpacing.s3),
                      ShrinkToFit(
                        maxWidth: constraints.maxWidth * 0.3,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(action, style: BipaText.label.copyWith(color: colors.onCamera)),
                      ),
                    ] else ...[
                      const SizedBox(width: BipaSpacing.s1),
                      Icon(Icons.chevron_right_rounded, size: 20, color: colors.onCamera),
                    ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
    // Tocável, a área de toque tem 48 de altura, como a dos outros botões.
    return onTap == null ? chip : TapTarget(onTap: onTap, child: chip);
  }
}

/// Um anel que esvazia em [duration], em volta de [child]. Com animações
/// desligadas no aparelho, fica cheio.
class _CountdownRing extends StatelessWidget {
  const _CountdownRing({required this.duration, required this.color, required this.child});

  final Duration duration;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return SizedBox.square(
      dimension: 22,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 1, end: still ? 1 : 0),
        duration: still ? Duration.zero : duration,
        builder: (context, left, child) => CustomPaint(
          painter: _RingPainter(fraction: left, color: color),
          child: Center(child: child),
        ),
        child: child,
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.fraction, required this.color});

  final double fraction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(1.5);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * fraction,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) => oldDelegate.fraction != fraction || oldDelegate.color != color;
}

/// O disparo amarelo da câmera.
class ShutterButton extends StatelessWidget {
  const ShutterButton({required this.label, required this.onPressed, this.size = 68, super.key});

  final String label;
  final VoidCallback onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    void press() {
      HapticFeedback.lightImpact();
      onPressed();
    }

    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: press,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: colors.brand.withValues(alpha: 0.28), spreadRadius: 6)],
        ),
        child: Material(
          color: colors.brand,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: press,
            child: SizedBox.square(
              dimension: size,
              child: Icon(Icons.qr_code_scanner_rounded, size: size / 2, color: colors.onBrand),
            ),
          ),
        ),
      ),
    );
  }
}
