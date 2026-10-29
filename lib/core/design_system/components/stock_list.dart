import 'package:bipa/core/design_system/bipa_metrics.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/design_system/bipa_typography.dart';
import 'package:bipa/core/design_system/text_scale.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

/// Cartão que agrupa as linhas do estoque, com fios entre elas.
class StockList extends StatelessWidget {
  const StockList({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(BipaRadius.lg),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: BipaSpacing.s1),
        child: Column(
          children: [
            for (final (index, child) in children.indexed) ...[
              if (index > 0) Divider(indent: 68, endIndent: BipaSpacing.s4, color: colors.line),
              child,
            ],
          ],
        ),
      ),
    );
  }
}

/// Uma ação do gesto de deslizar a linha.
class StockSwipeAction {
  const StockSwipeAction({required this.label, required this.icon, required this.onTriggered});

  final String label;
  final IconData icon;
  final VoidCallback onTriggered;
}

/// Linha do estoque: miniatura, nome e medidor. Em repouso é só informação;
/// tocar abre o [editor] ali mesmo. Deslizar para a esquerda faz
/// [swipeLeft] (dar baixa) e para a direita [swipeRight] (pôr na lista).
class StockRow extends StatelessWidget {
  const StockRow({
    required this.id,
    required this.thumb,
    required this.name,
    required this.gauge,
    required this.expanded,
    required this.onTap,
    this.editor,
    this.swipeLeft,
    this.swipeRight,
    super.key,
  });

  /// Identifica a linha para o gesto (por exemplo, o id do produto).
  final String id;
  final Widget thumb;
  final String name;
  final Widget gauge;
  final bool expanded;
  final VoidCallback onTap;
  final Widget? editor;
  final StockSwipeAction? swipeLeft;
  final StockSwipeAction? swipeRight;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final editor = this.editor;

    final row = Material(
      color: colors.surface,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(BipaSpacing.s3, 10, BipaSpacing.s4, 10),
            child: Row(
              children: [
                thumb,
                const SizedBox(width: BipaSpacing.s3),
                Expanded(
                  child: Text(
                    name,
                    // Com letra grande o nome não é cortado (H9).
                    maxLines: isLargeText(context) ? null : 2,
                    overflow: isLargeText(context) ? TextOverflow.visible : TextOverflow.ellipsis,
                    style: BipaText.bodyLarge.copyWith(color: colors.ink),
                  ),
                ),
                const SizedBox(width: BipaSpacing.s3),
                gauge,
              ],
            ),
          ),
        ),
      ),
    );

    final left = swipeLeft;
    final right = swipeRight;
    final swipeable = left == null && right == null
        ? row
        : Dismissible(
            key: ValueKey('swipe-$id'),
            direction: switch ((left, right)) {
              (null, _) => DismissDirection.startToEnd,
              (_, null) => DismissDirection.endToStart,
              _ => DismissDirection.horizontal,
            },
            dismissThresholds: const {DismissDirection.startToEnd: 0.3, DismissDirection.endToStart: 0.3},
            // A linha nunca some: o gesto só dispara a ação e volta com mola.
            confirmDismiss: (direction) async {
              (direction == DismissDirection.endToStart ? left : right)?.onTriggered();
              return false;
            },
            background: _SwipeBackground(action: right, alignment: Alignment.centerLeft, color: colors.brandSoft),
            secondaryBackground: _SwipeBackground(
              action: left,
              alignment: Alignment.centerRight,
              color: colors.surfaceSunken,
            ),
            child: row,
          );

    // Os gestos de deslizar não existem para o leitor de tela: as mesmas
    // ações aparecem no menu de ações dele.
    final withActions = Semantics(
      customSemanticsActions: {
        if (right != null) CustomSemanticsAction(label: right.label): right.onTriggered,
        if (left != null) CustomSemanticsAction(label: left.label): left.onTriggered,
      },
      child: swipeable,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        withActions,
        AnimatedSize(
          duration: BipaMotion.slow,
          curve: BipaMotion.standard,
          alignment: Alignment.topCenter,
          child: expanded && editor != null
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(BipaSpacing.s4, 0, BipaSpacing.s4, BipaSpacing.s3),
                  child: editor,
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({required this.action, required this.alignment, required this.color});

  final StockSwipeAction? action;
  final Alignment alignment;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final action = this.action;
    final colors = context.colors;
    return ColoredBox(
      color: color,
      child: action == null
          ? const SizedBox.shrink()
          : Align(
              alignment: alignment,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: BipaSpacing.s6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(action.icon, size: 18, color: colors.ink),
                    const SizedBox(width: BipaSpacing.s2),
                    Text(action.label, style: BipaText.label.copyWith(color: colors.ink)),
                  ],
                ),
              ),
            ),
    );
  }
}

/// O editor que abre na linha: o stepper e, se houver, a ação de lista.
class StockRowEditor extends StatelessWidget {
  const StockRowEditor({required this.stepper, this.trailing, super.key});

  final Widget stepper;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final trailing = this.trailing;
    // Em telas estreitas (ou com fonte grande), o que vem depois do stepper
    // desce para a linha de baixo em vez de estourar.
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: BipaSpacing.s2,
      runSpacing: BipaSpacing.s2,
      children: [stepper, ?trailing],
    );
  }
}
