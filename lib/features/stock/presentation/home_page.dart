import 'dart:async';
import 'dart:io';

import 'package:bipa/core/design_system/bipa_metrics.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/design_system/bipa_typography.dart';
import 'package:bipa/core/design_system/components/bipa_search_bar.dart';
import 'package:bipa/core/design_system/components/bipa_toast.dart';
import 'package:bipa/core/design_system/components/dropdown_chip.dart';
import 'package:bipa/core/design_system/components/place_filter.dart';
import 'package:bipa/core/design_system/components/product_card.dart';
import 'package:bipa/core/design_system/components/product_category_icon.dart';
import 'package:bipa/core/design_system/components/product_thumb.dart';
import 'package:bipa/core/design_system/components/quantity_stepper.dart';
import 'package:bipa/core/design_system/components/section_header.dart';
import 'package:bipa/core/design_system/components/stock_list.dart';
import 'package:bipa/core/formatting/formatters.dart';
import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/core/navigation/routes.dart';
import 'package:bipa/core/widgets/async_value_view.dart';
import 'package:bipa/core/widgets/empty_state.dart';
import 'package:bipa/features/backup/presentation/backup_providers.dart';
import 'package:bipa/features/backup/presentation/restore_offer_card.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/products/domain/product_search.dart';
import 'package:bipa/features/products/presentation/product_photos.dart';
import 'package:bipa/features/products/presentation/scan_product.dart';
import 'package:bipa/features/settings/presentation/crash_reporting_ask_card.dart';
import 'package:bipa/features/shopping_list/domain/record_at_home.dart';
import 'package:bipa/features/shopping_list/domain/shopping_list_item.dart';
import 'package:bipa/features/shopping_list/presentation/home_change_snack_bar.dart';
import 'package:bipa/features/shopping_list/presentation/list_preview.dart';
import 'package:bipa/features/shopping_list/presentation/shopping_list_providers.dart';
import 'package:bipa/features/shopping_list/presentation/start_shopping.dart';
import 'package:bipa/features/stock/domain/stock_item.dart';
import 'package:bipa/features/stock/domain/stock_location.dart';
import 'package:bipa/features/stock/domain/stock_movement_reason.dart';
import 'package:bipa/features/stock/presentation/stock_display.dart';
import 'package:bipa/features/stock/presentation/stock_item_sheet.dart';
import 'package:bipa/features/stock/presentation/stock_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// O Início: o que tem em casa, com a prateleira do que está acabando no topo.
///
/// Segue o protótipo "Início" do design system: busca com bipar, locais como
/// categorias, a prateleira de "Acabando" e a lista com medidor de nível.
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  String _query = '';

  /// `null` mostra todos os locais.
  StockLocation? _place;

  /// Só uma linha fica aberta por vez.
  String? _expandedProductId;

  /// Se a linha aberta estava abaixo do "ter sempre" ao abrir: ao fechar,
  /// cruzar a linha num sentido ou no outro oferece mexer na lista (AB1).
  var _openedLow = false;

  /// As linhas que acabaram de receber "Usei um" e ficam em "Em casa"
  /// enquanto o aviso está na tela (AB3).
  final _settling = <String>{};

  /// O bipar da busca encontra: abre o produto do código (ou a folha
  /// "Embalagem nova", se ele for novo), como a busca por texto.
  Future<void> _findByBarcode() async {
    final scanned = await scanAndResolvePackage(context, ref);
    if (scanned == null || !mounted) return;
    await context.push(Routes.productDetail(scanned.product.id));
  }

  /// Abre ou fecha o editor da linha. Ao fechar uma linha cujo stepper
  /// cruzou o "ter sempre", oferece pôr na lista ou tirar dela: o stepper é
  /// correção e não mexe na lista sozinho (ADR 0019).
  void _toggleExpanded(StockEntry entry, List<StockEntry> entries, Set<String> onList) {
    final closingId = _expandedProductId;
    final closingWasLow = _openedLow;
    setState(() {
      final id = entry.product.id;
      _expandedProductId = closingId == id ? null : id;
      _openedLow = entry.item.isLow;
    });
    final closing = entries.where((e) => e.product.id == closingId).firstOrNull;
    if (closing == null || closing.item.isLow == closingWasLow) return;
    final listed = onList.contains(closing.product.id);
    final l10n = AppLocalizations.of(context);
    final (message, action) = switch ((closing.item.isLow, listed)) {
      (true, false) => (l10n.stockBelowTarget(closing.product.name), l10n.listAddToList),
      (false, true) => (l10n.stockBackToTarget(closing.product.name), l10n.listRemoveFromList),
      _ => (null, null),
    };
    if (message == null || action == null) return;
    showBipaToast(
      ScaffoldMessenger.of(context),
      message,
      actionLabel: action,
      onAction: () => unawaited(_toggleList(closing.product, onList: listed, notify: true)),
    );
  }

  /// O stepper da linha aberta: corrige o estoque. Não mexe na lista nem
  /// avisa: o botão do lado oposto já desfaz.
  Future<void> _adjust(Product product, double delta) async {
    final messenger = ScaffoldMessenger.of(context);
    final message = AppLocalizations.of(context).stockAdjustFailed;
    try {
      await ref
          .read(stockRepositoryProvider)
          .adjust(
            productId: product.id,
            delta: delta,
            reason: delta > 0 ? StockMovementReason.purchase : StockMovementReason.consumption,
          );
    } on Exception {
      // Como na tela do produto (H11): sem o aviso, o número não muda e nada
      // diz por quê.
      showBipaToast(messenger, message);
    }
  }

  /// Deslizar "Usei um": como o modo "Usei" da câmera, o que ficou abaixo do
  /// "ter sempre" vai para a lista, e o "Desfazer" volta os dois.
  Future<void> _used(Product product) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final record = ref.read(recordAtHomeProvider);
    final HomeChange? change;
    try {
      change = await record.used(product);
    } on Exception {
      showBipaToast(messenger, l10n.cameraAdjustFailed);
      return;
    }
    if (change == null || !mounted) return;
    // A linha fica no lugar, já com o anel do que está acabando, enquanto o
    // aviso está na tela; só depois vai para "Acabando" (AB3).
    setState(() => _settling.add(product.id));
    final notice = showHomeChangeSnackBar(messenger, l10n: l10n, record: record, product: product, change: change);
    unawaited(
      notice.closed.then((_) {
        if (mounted) setState(() => _settling.remove(product.id));
      }),
    );
  }

  /// Põe o produto na lista ou o tira de lá. Com [notify] (o gesto e o
  /// botão da linha), avisa o que mudou, com "Desfazer"; o "+" do cartão de
  /// "Acabando" mostra o próprio estado e dispensa o aviso.
  Future<void> _toggleList(Product product, {required bool onList, bool notify = false}) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final list = ref.read(shoppingListRepositoryProvider);
    final VoidCallback undo;
    final String message;
    try {
      // Guardado antes de mudar: o desfazer devolve o item como estava, com a
      // quantidade e, se já estava marcado como comprado, marcado.
      final before = [
        for (final entry in await list.watchAll().first)
          if (entry.item.productId == product.id) entry.item,
      ];
      if (onList) {
        await list.removeProduct(product.id);
        message = l10n.listItemRemoved(product.name);
      } else {
        await ref.read(putProductOnListProvider)(product);
        message = l10n.cameraToList(product.name);
      }
      // O `restore` não duplica: tira o que está agora e devolve o de antes.
      Future<void> restoreBefore() async {
        await list.removeProduct(product.id);
        for (final item in before) {
          await list.restore(item);
        }
      }

      undo = () => unawaited(restoreBefore());
    } on Exception {
      showBipaToast(messenger, l10n.listUpdateFailed);
      return;
    }
    if (!notify) return;
    showBipaToast(messenger, message, actionLabel: l10n.undo, onAction: undo);
  }

  /// A mesma busca da aba Produtos (G7): palavra por palavra, em qualquer
  /// ordem e sem ligar para acento ("acucar" acha "Açúcar refinado").
  List<StockEntry> _visible(List<StockEntry> entries) => [
    for (final entry in entries)
      if ((_place == null || entry.item.location == _place) && matchesProductSearch(_query, name: entry.product.name))
        entry,
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final stock = ref.watch(stockProvider);
    final photos = ref.watch(productPhotosDirectoryProvider).value;
    final onList = ref.watch(productsOnListProvider);
    final listEntries = ref.watch(shoppingListProvider).value ?? const <ShoppingListEntry>[];
    final listSummary = ref.watch(shoppingListSummaryProvider);
    // Durante a compra, a prévia dá lugar à barra da compra.
    final shopping = ref.watch(activeTripProvider).value != null;
    final restoreOffer = ref.watch(backupProvider.select((state) => state.value?.restoreOffer));

    return Scaffold(
      body: AsyncValueView(
        value: stock,
        onRetry: () => ref.invalidate(stockProvider),
        data: (entries) {
          final visible = _visible(entries);
          // Acabou primeiro, depois o que está mais perto de acabar.
          // A linha aberta fica em "Em casa" enquanto é editada, mesmo que caia
          // abaixo do "ter sempre": assim o editor não some debaixo do dedo. A
          // que acabou de receber "Usei um" também, enquanto o aviso aparece.
          bool inShelf(StockEntry e) =>
              e.item.isLow && e.product.id != _expandedProductId && !_settling.contains(e.product.id);
          final low = visible.where(inShelf).toList()
            ..sort((a, b) => a.item.fillFraction.compareTo(b.item.fillFraction));
          final atHome = visible.where((e) => !inShelf(e)).toList();

          return CustomScrollView(
            slivers: [
              SliverSafeArea(
                bottom: false,
                sliver: SliverPadding(
                  padding: const EdgeInsets.fromLTRB(BipaSpacing.s4, BipaSpacing.s6, BipaSpacing.s4, 0),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Semantics(
                                header: true,
                                child: Text(
                                  l10n.homeTitle,
                                  style: BipaText.headline.copyWith(color: context.colors.ink),
                                ),
                              ),
                            ),
                            const SizedBox(width: BipaSpacing.s3),
                            // Os Ajustes (ADR 0025): o botão redondo das outras telas.
                            IconButton.filled(
                              tooltip: l10n.settingsTitle,
                              style: IconButton.styleFrom(
                                backgroundColor: context.colors.surface,
                                foregroundColor: context.colors.ink,
                                fixedSize: const Size.square(48),
                              ),
                              onPressed: () => context.push(Routes.settings),
                              icon: const Icon(Icons.settings_outlined),
                            ),
                          ],
                        ),
                        const SizedBox(height: BipaSpacing.s4),
                        BipaSearchBar(
                          hint: l10n.searchHome,
                          onChanged: (value) => setState(() => _query = value),
                          onScan: _findByBarcode,
                          scanLabel: l10n.searchScan,
                        ),
                        if (listSummary.remaining > 0 && !shopping) ...[
                          const SizedBox(height: BipaSpacing.s4),
                          ListPreview(
                            entries: listEntries,
                            summary: listSummary,
                            photos: photos,
                            onGoShopping: () => startShopping(context, ref),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              // Celular novo, com o backup do antigo trazido pelo Android: o
              // cartão "Backup encontrado" fica no lugar do convite da casa
              // vazia (ADR 0023, B1). Com a casa já em uso, o cartão menor
              // fica no lugar da pergunta do relatório de falhas (BK1).
              if (entries.isEmpty && restoreOffer != null)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(BipaSpacing.s4, BipaSpacing.s6, BipaSpacing.s4, 0),
                  sliver: SliverToBoxAdapter(child: RestoreOfferCard(offer: restoreOffer)),
                )
              // Casa vazia: a busca e a prévia da lista continuam, e o convite
              // a bipar o que há em casa fica embaixo.
              else if (entries.isEmpty)
                SliverToBoxAdapter(
                  child: EmptyState(
                    icon: Icons.kitchen_outlined,
                    message: l10n.homeEmpty,
                    actionLabel: l10n.homeEmptyAction,
                    // A câmera fica aberta somando cada código em casa ("Comprei").
                    onAction: () => context.push(Routes.cameraBought),
                  ),
                )
              else
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: BipaSpacing.s6),
                    child: _PlaceFilter(
                      entries: entries,
                      selected: _place,
                      onSelected: (p) => setState(() => _place = p),
                    ),
                  ),
                ),
              if (entries.isNotEmpty && visible.isEmpty)
                SliverPadding(
                  padding: const EdgeInsets.all(BipaSpacing.s8),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      l10n.homeNoResults,
                      textAlign: TextAlign.center,
                      style: BipaText.body.copyWith(color: context.colors.inkMuted),
                    ),
                  ),
                ),
              if (low.isNotEmpty) ...[
                _sectionHeader(SectionHeader(title: l10n.sectionRunningLow, count: low.length, alert: true)),
                SliverToBoxAdapter(
                  child: SizedBox(
                    // O cartão e a folga para a sombra do "+".
                    height:
                        ProductCard.heightFor(context, names: [for (final entry in low) entry.product.name]) +
                        BipaSpacing.s3,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: BipaSpacing.s4),
                      itemCount: low.length,
                      separatorBuilder: (_, _) => const SizedBox(width: BipaSpacing.s3),
                      itemBuilder: (context, index) {
                        final entry = low[index];
                        final isOnList = onList.contains(entry.product.id);
                        return ProductCard(
                          name: entry.product.name,
                          image: _ProductArt(product: entry.product, photo: productPhotoFile(entry.product, photos)),
                          gauge: entry.item.gauge(l10n, size: 36),
                          // O toque abre o mesmo editor da linha (Comprei um, lista,
                          // "ter sempre"); o toque longo, o produto.
                          onTap: () => showStockItemSheet(context, entry.product),
                          onLongPress: () => context.push(Routes.productDetail(entry.product.id)),
                          onList: isOnList,
                          onToggleList: () => _toggleList(entry.product, onList: isOnList),
                          addLabel: l10n.listAddToList,
                          removeLabel: l10n.listRemoveFromList,
                        );
                      },
                    ),
                  ),
                ),
              ],
              // A pergunta do relatório de falhas: depois de "Acabando", que é
              // o que o Início existe para mostrar, e só uma vez (ADR 0025).
              // Com busca ou local escolhido some, para não empurrar os
              // resultados para baixo do teclado (H18). O backup de outro
              // celular sem resposta, com a casa em uso, fica no lugar dela:
              // uma pergunta por vez (protótipo InicioBackupPendente).
              if (_query.trim().isEmpty && _place == null)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: BipaSpacing.s4),
                  sliver: SliverToBoxAdapter(
                    child: entries.isNotEmpty && restoreOffer != null
                        ? PendingBackupCard(offer: restoreOffer)
                        : const CrashReportingAskCard(),
                  ),
                ),
              if (atHome.isNotEmpty) ...[
                _sectionHeader(SectionHeader(title: l10n.sectionAtHome, count: atHome.length)),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: BipaSpacing.s4),
                  sliver: SliverToBoxAdapter(
                    child: StockList(
                      children: [
                        for (final entry in atHome)
                          _HomeStockRow(
                            entry: entry,
                            photo: productPhotoFile(entry.product, photos),
                            expanded: _expandedProductId == entry.product.id,
                            onList: onList.contains(entry.product.id),
                            onToggleList: () =>
                                _toggleList(entry.product, onList: onList.contains(entry.product.id), notify: true),
                            onTap: () => _toggleExpanded(entry, visible, onList),
                            onAdjust: (delta) => _adjust(entry.product, delta),
                            onUsed: () => _used(entry.product),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
              // Espaço para as barras flutuantes (navegação e compra).
              SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).bottom + BipaSpacing.s4)),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionHeader(Widget header) => SliverPadding(
    padding: const EdgeInsets.fromLTRB(BipaSpacing.s4, BipaSpacing.s6, BipaSpacing.s4, BipaSpacing.s2),
    sliver: SliverToBoxAdapter(child: header),
  );
}

class _PlaceFilter extends StatelessWidget {
  const _PlaceFilter({required this.entries, required this.selected, required this.onSelected});

  final List<StockEntry> entries;
  final StockLocation? selected;
  final ValueChanged<StockLocation?> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final counts = <StockLocation, int>{};
    for (final entry in entries) {
      counts.update(entry.item.location, (count) => count + 1, ifAbsent: () => 1);
    }
    // Os locais em uso, do que tem mais itens para o que tem menos.
    final places = counts.keys.toList()..sort((a, b) => counts[b]!.compareTo(counts[a]!));

    return PlaceFilter<StockLocation?>(
      selected: selected,
      onSelected: onSelected,
      options: [
        PlaceOption(value: null, label: l10n.placeAll, icon: Icons.grid_view_rounded, count: entries.length),
        for (final place in places)
          PlaceOption(value: place, label: place.localizedLabel(l10n), icon: place.icon, count: counts[place]!),
      ],
    );
  }
}

/// Arte do cartão de produto: a foto cobrindo o quadro ou o ícone da categoria.
class _ProductArt extends StatelessWidget {
  const _ProductArt({required this.product, required this.photo});

  final Product product;
  final File? photo;

  @override
  Widget build(BuildContext context) {
    final icon = Center(child: Icon(productCategoryIcon(product.name), size: 46, color: context.colors.ink));
    final file = photo;
    if (file == null) return icon;
    return Image.file(file, fit: BoxFit.cover, gaplessPlayback: true, errorBuilder: (_, _, _) => icon);
  }
}

typedef _Adjust = Future<void> Function(double delta);

class _HomeStockRow extends StatelessWidget {
  const _HomeStockRow({
    required this.entry,
    required this.photo,
    required this.expanded,
    required this.onList,
    required this.onToggleList,
    required this.onTap,
    required this.onAdjust,
    required this.onUsed,
  });

  final StockEntry entry;
  final File? photo;
  final bool expanded;
  final bool onList;
  final VoidCallback onToggleList;
  final VoidCallback onTap;
  final _Adjust onAdjust;
  final VoidCallback onUsed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final item = entry.item;
    final product = entry.product;

    return StockRow(
      id: product.id,
      thumb: ProductThumb(
        photo: photo,
        fallbackIcon: productCategoryIcon(product.name),
        dimmed: item.isOut,
        badgeLabel: onList ? l10n.listOnList : null,
      ),
      name: product.name,
      gauge: item.gauge(l10n),
      expanded: expanded,
      onTap: onTap,
      swipeLeft: item.isOut
          ? null
          : StockSwipeAction(label: l10n.stockUsedOne, icon: Icons.remove_rounded, onTriggered: onUsed),
      swipeRight: StockSwipeAction(
        label: onList ? l10n.listRemoveFromList : l10n.listAddToList,
        icon: onList ? Icons.playlist_remove_rounded : Icons.playlist_add_rounded,
        onTriggered: onToggleList,
      ),
      editor: StockRowEditor(
        stepper: QuantityStepper(
          value: item.quantityLabel,
          unit: l10n.unitPackages,
          valueSpoken: l10n.stockAtHomeSpoken(item.quantity, item.quantityLabel),
          decrementLabel: l10n.stockOneLess,
          incrementLabel: l10n.stockOneMore,
          highlighted: item.isLow,
          onIncrement: () => onAdjust(1),
          onDecrement: item.isOut ? null : () => onAdjust(-1),
        ),
        // Wrap: com letra grande, o chip do "ter sempre" desce para a linha de
        // baixo em vez de estourar a linha (H3).
        trailing: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            IconButton(
              tooltip: onList ? l10n.listRemoveFromList : l10n.listAddToList,
              onPressed: onToggleList,
              isSelected: onList,
              icon: const Icon(Icons.playlist_add_rounded),
              selectedIcon: const Icon(Icons.playlist_add_check_rounded),
            ),
            // O "ter sempre" à vista, com o valor: tocar abre o editor.
            DropdownChip(
              icon: Icons.flag_outlined,
              label: switch (item.targetQuantity) {
                final target? => l10n.productTargetCount(Formatters.quantity(target)),
                null => l10n.productTargetCount(l10n.stockTargetNone),
              },
              // "Ter sempre —" seria lido "travessão" (H4).
              semanticsLabel: item.targetQuantity == null ? l10n.productTargetSpokenNone : null,
              onTap: () => showStockItemSheet(context, product),
            ),
            // O resto do item (local, "Tirar de casa", produto) sem passar
            // pelo chip do "ter sempre" (AB6).
            IconButton(
              tooltip: l10n.stockItemMore,
              onPressed: () => showStockItemSheet(context, product),
              icon: const Icon(Icons.more_horiz_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
