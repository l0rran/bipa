import 'dart:ui' show ImageFilter;

import 'package:bipa/core/design_system/bipa_metrics.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/design_system/bipa_typography.dart';
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
    this.maxListHeight = 196,
    super.key,
  });

  final String title;

  /// "4 de 7 da lista".
  final String? countLabel;

  /// "Vou levar".
  final String totalLabel;

  /// "R$ 54,88"; sem nenhum preço, o total não aparece.
  final String? totalValue;
  final List<Widget> items;
  final Widget footer;

  /// A bandeja mostra os últimos itens e rola o resto, sem cobrir a câmera.
  final double maxListHeight;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final countLabel = this.countLabel;
    final totalValue = this.totalValue;

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
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: ShapeDecoration(color: colors.line, shape: const StadiumBorder()),
                ),
              ),
              const SizedBox(height: BipaSpacing.s3),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: BipaSpacing.s1),
                child: Row(
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            totalLabel.toUpperCase(),
                            style: BipaText.caption.copyWith(fontSize: 11, height: 14 / 11, color: colors.inkMuted),
                          ),
                          Text(
                            totalValue,
                            style: BipaText.price.copyWith(fontSize: 22, height: 26 / 22, color: colors.ink),
                          ),
                        ],
                      ),
                  ],
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
    this.justRead = false,
    super.key,
  });

  /// Nome do produto, já com a quantidade quando passa de um ("2× Café").
  final String name;

  /// "R$ 27,90"; `null` mostra um traço para digitar.
  final String? price;
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

    return Container(
      padding: const EdgeInsets.fromLTRB(BipaSpacing.s3, BipaSpacing.s2, BipaSpacing.s2, BipaSpacing.s2),
      decoration: BoxDecoration(color: colors.ground, borderRadius: BorderRadius.circular(BipaRadius.md)),
      child: Row(
        children: [
          Expanded(
            child: AnimatedOpacity(
              opacity: dimmed,
              duration: BipaMotion.base,
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: BipaText.label.copyWith(fontWeight: FontWeight.w600, color: colors.ink),
              ),
            ),
          ),
          const SizedBox(width: BipaSpacing.s3),
          AnimatedOpacity(
            opacity: dimmed,
            duration: BipaMotion.base,
            child: Semantics(
              button: true,
              label: price ?? priceTapLabel,
              excludeSemantics: true,
              onTap: onPriceTap,
              child: AnimatedContainer(
                duration: BipaMotion.base,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(BipaRadius.sm),
                  boxShadow: [if (justRead) BoxShadow(color: colors.brandSoft, spreadRadius: 3)],
                ),
                child: Material(
                  color: price == null ? colors.surfaceSunken : colors.price,
                  borderRadius: BorderRadius.circular(BipaRadius.sm),
                  child: InkWell(
                    onTap: onPriceTap,
                    borderRadius: BorderRadius.circular(BipaRadius.sm),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      child: Text(
                        price ?? '—',
                        style: BipaText.number.copyWith(
                          fontSize: 14,
                          height: 18 / 14,
                          color: price == null ? colors.inkMuted : colors.onPrice,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: BipaSpacing.s3),
          BipaToggle(value: take, onChanged: onTakeChanged, semanticLabel: takeLabel),
        ],
      ),
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
        onTap: () => onChanged(!value),
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
  late final _sweep = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);

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
            Align(alignment: corner, child: _Corner(alignment: corner, color: cornerColor)),
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(BipaRadius.pill),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Material(
            color: colors.camera.withValues(alpha: 0.55),
            child: InkWell(
              onTap: onTap,
              child: Container(
                height: 40,
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
    );
  }
}

/// Aviso da leitura ao vivo sobre a câmera (protótipo "Modo carrinho: preço
/// lido"): o preço da etiqueta em destaque e, ao lado, o item que o recebeu
/// ou o que falta fazer. Não é tocável; o leitor de tela anuncia a mudança.
class LiveReadChip extends StatelessWidget {
  const LiveReadChip({required this.icon, required this.price, required this.detail, super.key});

  final IconData icon;

  /// "R$ 27,90".
  final String price;

  /// O nome do item ou "bipe o produto".
  final String detail;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      liveRegion: true,
      label: '$price, $detail',
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(BipaRadius.pill),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            height: 40,
            color: colors.camera.withValues(alpha: 0.55),
            padding: const EdgeInsets.only(left: BipaSpacing.s3, right: BipaSpacing.s4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: colors.onCamera),
                const SizedBox(width: BipaSpacing.s2),
                Text(price, style: BipaText.number.copyWith(fontSize: 16, height: 20 / 16, color: colors.onCamera)),
                const SizedBox(width: BipaSpacing.s2),
                Flexible(
                  child: Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BipaText.caption.copyWith(color: colors.onCamera.withValues(alpha: 0.75)),
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
