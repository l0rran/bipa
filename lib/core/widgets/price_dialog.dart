import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/core/money/money.dart';
import 'package:flutter/material.dart';

/// Pergunta um preço, com o campo já preenchido com [initial]. Devolve o
/// preço digitado (maior que zero), ou `null` em "Cancelar".
Future<Money?> showPriceDialog(BuildContext context, {required String title, Money? initial}) => showDialog<Money>(
  context: context,
  builder: (_) => _PriceDialog(title: title, initial: initial),
);

/// O diálogo de digitar o preço, dono do próprio campo: o controller só é
/// descartado quando o diálogo sai da árvore, depois da animação.
class _PriceDialog extends StatefulWidget {
  const _PriceDialog({required this.title, this.initial});

  final String title;
  final Money? initial;

  @override
  State<_PriceDialog> createState() => _PriceDialogState();
}

class _PriceDialogState extends State<_PriceDialog> {
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
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(prefixText: r'R$ '),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.cancel)),
        FilledButton(onPressed: _submit, child: Text(l10n.save)),
      ],
    );
  }
}
