import 'package:bipa/core/design_system/bipa_metrics.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/design_system/bipa_typography.dart';
import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/core/money/money.dart';
import 'package:flutter/material.dart';

/// A conta de volta que o diálogo mostra sob o campo: o [text] da tela
/// ("1,38 kg a R$ 8,99/kg") e o que o leitor de tela diz dele ([spoken]).
typedef WeighedBack = ({String text, String spoken});

/// Pergunta quanto deu uma pesagem (protótipo "Modo carrinho: quanto deu o
/// granel"): o campo grande, com o valor já preenchido com [initial], e, sob
/// ele, a conta de volta de [backFor] (o peso que o valor dá pelo preço por
/// quilo), para conferir de cabeça. Devolve o valor digitado (maior que
/// zero), ou `null` em "Cancelar".
///
/// O [title] pergunta ("Quanto deu o Tomate italiano?"), para separar do
/// preço da gôndola. [backFor] devolve `null` quando não há conta a fazer (o
/// valor ainda não vale ou o produto não tem preço por quilo).
Future<Money?> showWeighedValueDialog(
  BuildContext context, {
  required String title,
  required WeighedBack? Function(Money value) backFor,
  Money? initial,
}) => showDialog<Money>(
  context: context,
  builder: (_) => _WeighedValueDialog(title: title, backFor: backFor, initial: initial),
);

/// O diálogo, dono do próprio campo: o controller só é descartado quando ele
/// sai da árvore, depois da animação.
class _WeighedValueDialog extends StatefulWidget {
  const _WeighedValueDialog({required this.title, required this.backFor, this.initial});

  final String title;
  final WeighedBack? Function(Money value) backFor;
  final Money? initial;

  @override
  State<_WeighedValueDialog> createState() => _WeighedValueDialogState();
}

class _WeighedValueDialogState extends State<_WeighedValueDialog> {
  late final _controller = TextEditingController(text: widget.initial?.formatDecimal() ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final money = Money.tryParse(_controller.text);
    if (money != null && money.isPositive) Navigator.of(context).pop(money);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    // O anel de foco do design system: escuro no claro, amarelo no escuro.
    final ring = Theme.of(context).brightness == Brightness.dark
        ? colors.brand.withValues(alpha: 0.55)
        : colors.ink.withValues(alpha: 0.35);
    return Dialog(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: BipaSpacing.s6, vertical: BipaSpacing.s6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, BipaSpacing.s6, 20, BipaSpacing.s4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(widget.title, style: BipaText.title.copyWith(color: colors.ink)),
            ),
            const SizedBox(height: BipaSpacing.s4),
            Container(
              constraints: const BoxConstraints(minHeight: 64),
              padding: const EdgeInsets.symmetric(horizontal: BipaSpacing.s4),
              decoration: BoxDecoration(
                color: colors.surfaceSunken,
                borderRadius: BorderRadius.circular(BipaRadius.md),
                boxShadow: [BoxShadow(color: ring, spreadRadius: 3)],
              ),
              child: Row(
                children: [
                  Text(
                    Money.symbol,
                    style: BipaText.title.copyWith(fontSize: 16, height: 20 / 16, color: colors.inkMuted),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Semantics(
                      label: l10n.cartWeighingValueField,
                      child: TextField(
                        controller: _controller,
                        autofocus: true,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        cursorColor: colors.ink,
                        cursorHeight: 30,
                        style: BipaText.headline.copyWith(fontSize: 30, height: 36 / 30, color: colors.ink),
                        decoration: const InputDecoration.collapsed(hintText: null),
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) => _submit(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _back(context),
            const SizedBox(height: BipaSpacing.s4),
            OverflowBar(
              alignment: MainAxisAlignment.end,
              spacing: BipaSpacing.s2,
              overflowAlignment: OverflowBarAlignment.end,
              overflowSpacing: BipaSpacing.s2,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.ink,
                    foregroundColor: colors.surface,
                    minimumSize: const Size(0, 48),
                  ),
                  child: Text(l10n.save),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// A conta de volta, com a balança: some enquanto não há conta a fazer.
  Widget _back(BuildContext context) {
    final colors = context.colors;
    final value = Money.tryParse(_controller.text);
    final back = value == null ? null : widget.backFor(value);
    if (back == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: BipaSpacing.s2),
      child: Semantics(
        label: back.spoken,
        excludeSemantics: true,
        child: Row(
          children: [
            Icon(Icons.scale_outlined, size: 16, color: colors.inkMuted),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                back.text,
                style: BipaText.label.copyWith(fontSize: 13, height: 18 / 13, color: colors.inkMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
