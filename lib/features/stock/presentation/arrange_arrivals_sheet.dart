import 'package:bipa/core/design_system/bipa_metrics.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/design_system/bipa_typography.dart';
import 'package:bipa/core/design_system/components/choice_chips.dart';
import 'package:bipa/core/design_system/components/group_label.dart';
import 'package:bipa/core/design_system/components/product_category_icon.dart';
import 'package:bipa/core/design_system/components/product_thumb.dart';
import 'package:bipa/core/design_system/components/quantity_stepper.dart';
import 'package:bipa/core/design_system/components/section_header.dart';
import 'package:bipa/core/design_system/components/stock_list.dart';
import 'package:bipa/core/formatting/formatters.dart';
import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/products/presentation/product_photos.dart';
import 'package:bipa/features/stock/domain/stock_item.dart';
import 'package:bipa/features/stock/domain/stock_location.dart';
import 'package:bipa/features/stock/presentation/place_choice_sheet.dart';
import 'package:bipa/features/stock/presentation/stock_display.dart';
import 'package:bipa/features/stock/presentation/stock_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Abre "Arrumar o que entrou" (AB5) com [arrivals], os itens que nasceram
/// em casa nesta câmera, na ordem em que entraram. Não devolve nada: cada
/// toque já salvou, e fechar é pular.
Future<void> showArrangeArrivalsSheet(BuildContext context, List<StockEntry> arrivals) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  useSafeArea: true,
  isScrollControlled: true,
  builder: (_) => ArrangeArrivalsSheet(arrivals: arrivals),
);

/// A folha "Arrumar o que entrou" (protótipo "ArrumarEntrou"): os itens que
/// entraram, agrupados pelo local em que nasceram (o sugerido ou o
/// lembrado). Tocar num item abre ali mesmo a escolha do local e o "ter
/// sempre", como a linha do Início; um item aberto por vez.
///
/// Os grupos são os da abertura: trocar o local de um item marca o chip
/// novo, mas a linha não pula para outro grupo enquanto a pessoa mexe nela.
class ArrangeArrivalsSheet extends ConsumerStatefulWidget {
  const ArrangeArrivalsSheet({required this.arrivals, super.key});

  final List<StockEntry> arrivals;

  @override
  ConsumerState<ArrangeArrivalsSheet> createState() => _ArrangeArrivalsSheetState();
}

class _ArrangeArrivalsSheetState extends ConsumerState<ArrangeArrivalsSheet> {
  /// O item aberto. Começa no primeiro da folha, como no protótipo, para
  /// mostrar o que a linha faz.
  late String? _openId = _groups.firstOrNull?.$2.first.product.id;

  /// Os itens de cada local na abertura, na ordem dos locais e, dentro de
  /// cada um, na ordem em que entraram.
  late final List<(StockLocation, List<StockEntry>)> _groups = [
    for (final location in StockLocation.values)
      if (widget.arrivals.where((entry) => entry.item.location == location).toList() case final entries
          when entries.isNotEmpty)
        (location, entries),
  ];

  /// Executa uma mudança no estoque e, se o banco falhar, avisa como a
  /// folha do item (H11).
  Future<void> _guard(Future<void> Function() change) async {
    final messenger = ScaffoldMessenger.of(context);
    final message = AppLocalizations.of(context).stockAdjustFailed;
    try {
      await change();
    } on Exception {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _toggle(String productId) => setState(() => _openId = _openId == productId ? null : productId);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final stock = ref.watch(stockRepositoryProvider);
    final photos = ref.watch(productPhotosDirectoryProvider).value;
    // O estado de agora de cada item; enquanto o banco não responde (ou se o
    // item sumiu nesse meio-tempo), o da abertura.
    final live = {for (final entry in ref.watch(stockProvider).value ?? const <StockEntry>[]) entry.product.id: entry};

    Widget row(StockEntry opened) {
      final entry = live[opened.product.id] ?? opened;
      final product = entry.product;
      final item = entry.item;
      return StockRow(
        id: product.id,
        thumb: ProductThumb(
          photo: productPhotoFile(product, photos),
          fallbackIcon: productCategoryIcon(product.name),
          dimmed: item.isOut,
        ),
        name: product.name,
        gauge: item.gauge(l10n),
        expanded: _openId == product.id,
        onTap: () => _toggle(product.id),
        editor: _ArrivalEditor(
          product: product,
          item: item,
          onLocation: (location) => _guard(() => stock.setLocation(product.id, location)),
          onTarget: (target) => _guard(() => stock.setTargetQuantity(product.id, target)),
        ),
      );
    }

    return ConstrainedBox(
      // A folha cresce com a lista até perto do topo, com a câmera aparecendo
      // atrás, e rola dali em diante.
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: BipaSpacing.s4),
            child: Semantics(
              header: true,
              label: l10n.arrangeArrivalsHeading(widget.arrivals.length),
              excludeSemantics: true,
              child: SectionHeader(title: l10n.arrangeArrivalsTitle, count: widget.arrivals.length),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: BipaSpacing.s2),
              children: [
                for (final (location, entries) in _groups) ...[
                  GroupLabel(
                    title: location.localizedLabel(l10n),
                    count: entries.length,
                    semanticsLabel: l10n.arrangeArrivalsGroup(location.localizedLabel(l10n), entries.length),
                  ),
                  StockList(children: [for (final entry in entries) row(entry)]),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(BipaSpacing.s4, BipaSpacing.s3, BipaSpacing.s4, BipaSpacing.s4),
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colors.ink,
                foregroundColor: colors.surface,
                minimumSize: const Size.fromHeight(56),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.arrangeArrivalsDone),
            ),
          ),
        ],
      ),
    );
  }
}

/// O que abre na linha: os locais em chips e o "ter sempre".
class _ArrivalEditor extends StatelessWidget {
  const _ArrivalEditor({required this.product, required this.item, required this.onLocation, required this.onTarget});

  final Product product;
  final StockItem item;
  final ValueChanged<StockLocation> onLocation;
  final ValueChanged<double?> onTarget;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final target = item.targetQuantity;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ChoiceChips<StockLocation>(
          options: stockLocationOptions(l10n),
          selected: item.location,
          semanticsLabel: l10n.stockPlaceQuestion(product.name),
          onSelected: (location) {
            if (location != item.location) onLocation(location);
          },
        ),
        const SizedBox(height: BipaSpacing.s2),
        Row(
          children: [
            // O stepper já diz "ter sempre 2 embalagens" ao leitor de tela.
            Expanded(
              child: ExcludeSemantics(
                child: Text(l10n.stockSheetTarget, style: BipaText.label.copyWith(color: colors.ink)),
              ),
            ),
            const SizedBox(width: BipaSpacing.s3),
            // "Ter sempre": − até 1 e depois some (sem alerta); + a partir do
            // nada começa em 1, como na folha do item.
            QuantityStepper(
              value: target == null ? l10n.stockTargetNone : Formatters.quantity(target),
              unit: l10n.unitPackages,
              valueSpoken: target == null
                  ? l10n.stockTargetNoneSpoken
                  : l10n.stockTargetSpoken(target, Formatters.quantity(target)),
              decrementLabel: l10n.stockTargetLess,
              incrementLabel: l10n.stockTargetMore,
              onIncrement: () => onTarget((target ?? 0) + 1),
              onDecrement: target == null ? null : () => onTarget(target <= 1 ? null : target - 1),
            ),
          ],
        ),
      ],
    );
  }
}
