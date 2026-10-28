import 'package:bipa/core/design_system/bipa_metrics.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/design_system/bipa_typography.dart';
import 'package:bipa/core/design_system/components/price_tag.dart';
import 'package:bipa/core/di/core_providers.dart';
import 'package:bipa/core/formatting/calendar_days.dart';
import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/core/widgets/price_dialog.dart';
import 'package:bipa/features/prices/domain/price_observation.dart';
import 'package:bipa/features/prices/domain/price_source.dart';
import 'package:bipa/features/prices/domain/register_price_observation.dart';
import 'package:bipa/features/prices/presentation/prices_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Abre a folha de um preço do histórico (F3): o valor, há quanto tempo, e
/// "Corrigir o preço", que grava a correção como no carrinho (ADR 0017). A
/// leitura errada sai do histórico, do gráfico e do "menor por kg" sem ser
/// apagada. [openLabel] e [onOpen] levam ao lugar da linha: o mercado, na
/// tela do produto, ou o produto, na tela do mercado.
Future<void> showPriceSheet(
  BuildContext context, {
  required PriceObservation observation,
  required String title,
  required String openLabel,
  required VoidCallback onOpen,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => PriceSheet(observation: observation, title: title, openLabel: openLabel, onOpen: onOpen),
);

class PriceSheet extends ConsumerStatefulWidget {
  const PriceSheet({
    required this.observation,
    required this.title,
    required this.openLabel,
    required this.onOpen,
    super.key,
  });

  final PriceObservation observation;

  /// O mercado (na tela do produto) ou o produto (na do mercado).
  final String title;
  final String openLabel;
  final VoidCallback onOpen;

  @override
  ConsumerState<PriceSheet> createState() => _PriceSheetState();
}

class _PriceSheetState extends ConsumerState<PriceSheet> {
  var _saving = false;

  Future<void> _correct() async {
    final l10n = AppLocalizations.of(context);
    final register = ref.read(registerPriceObservationProvider);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final observation = widget.observation;
    final price = await showPriceDialog(context, title: l10n.confirmEditPrice, initial: observation.price);
    if (price == null || price == observation.price || !mounted) return;
    setState(() => _saving = true);
    try {
      await register(
        RegisterPriceInput(
          marketId: observation.marketId,
          productId: observation.productId,
          packageId: observation.packageId,
          price: price,
          condition: observation.condition,
          source: PriceSource.manual,
          supersedes: observation.id,
          // O preço certo é o daquele dia: a correção fica na mesma data.
          observedAt: observation.observedAt,
        ),
      );
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text(l10n.priceCorrected)));
    } on Exception {
      messenger.showSnackBar(SnackBar(content: Text(l10n.priceCorrectFailed)));
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final now = ref.watch(clockProvider)();
    final days = calendarDaysSince(widget.observation.observedAt, now);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        BipaSpacing.s4,
        0,
        BipaSpacing.s4,
        BipaSpacing.s4 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(widget.title, style: BipaText.headline.copyWith(fontSize: 22, color: colors.ink)),
          ),
          const SizedBox(height: BipaSpacing.s4),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: PriceTagHero(price: widget.observation.price, unitLine: l10n.priceAge(days)),
          ),
          const SizedBox(height: BipaSpacing.s6),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colors.ink,
              foregroundColor: colors.surface,
              minimumSize: const Size.fromHeight(56),
            ),
            onPressed: _saving ? null : _correct,
            child: Text(l10n.confirmEditPrice),
          ),
          const SizedBox(height: BipaSpacing.s2),
          OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
            onPressed: () {
              Navigator.of(context).pop();
              widget.onOpen();
            },
            child: Text(widget.openLabel),
          ),
        ],
      ),
    );
  }
}
