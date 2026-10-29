import 'package:bipa/core/design_system/bipa_metrics.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/design_system/bipa_typography.dart';
import 'package:bipa/core/design_system/components/bipa_search_bar.dart';
import 'package:bipa/core/design_system/components/price_rows.dart';
import 'package:bipa/core/design_system/components/product_category_icon.dart';
import 'package:bipa/core/di/core_providers.dart';
import 'package:bipa/core/formatting/calendar_days.dart';
import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/core/l10n/meta_join.dart';
import 'package:bipa/core/navigation/routes.dart';
import 'package:bipa/core/widgets/async_value_view.dart';
import 'package:bipa/core/widgets/empty_state.dart';
import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:bipa/features/products/presentation/product_rows_providers.dart';
import 'package:bipa/features/products/presentation/products_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Produtos (protótipo "Produtos"): a busca com o bipar dentro e os produtos
/// em ordem alfabética num cartão, cada um com o ícone da categoria, a
/// embalagem (ou quantas são) e o preço. Segue a tela de Mercados.
///
/// A busca acha por nome, marca ou código de barras. "Cadastrar produto" fecha
/// a lista; o que antes ficava nos botões da barra (bipar, novo) está na busca
/// e nesta linha.
class ProductsPage extends ConsumerWidget {
  const ProductsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final rows = ref.watch(productRowsProvider);
    final now = ref.watch(clockProvider)();
    final searching = ref.watch(productSearchQueryProvider).trim().isNotEmpty;

    final addRow = PriceRowData(
      icon: Icons.add_rounded,
      title: l10n.productsAdd,
      onTap: () => context.push(Routes.newProduct),
    );

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          BipaSpacing.s4,
          MediaQuery.paddingOf(context).top + BipaSpacing.s6,
          BipaSpacing.s4,
          // Espaço para as barras flutuantes (navegação e compra).
          MediaQuery.paddingOf(context).bottom + BipaSpacing.s8,
        ),
        children: [
          Semantics(
            header: true,
            child: Text(l10n.navProducts, style: BipaText.headline.copyWith(color: context.colors.ink)),
          ),
          const SizedBox(height: BipaSpacing.s4),
          // O título e a busca ficam fora do carregamento: digitar refaz a
          // lista, e o campo não pode sumir debaixo do dedo.
          BipaSearchBar(
            hint: l10n.productsSearch,
            onChanged: ref.read(productSearchQueryProvider.notifier).change,
            onScan: () => context.push(Routes.cameraFind),
            scanLabel: l10n.searchScan,
          ),
          const SizedBox(height: BipaSpacing.s6),
          AsyncValueView(
            value: rows,
            onRetry: () => ref.invalidate(productsProvider),
            data: (items) {
              if (items.isEmpty && !searching) {
                // Sem nenhum produto: o convite fica embaixo da busca, que
                // já leva à câmera.
                return EmptyState(
                  icon: Icons.inventory_2_outlined,
                  message: l10n.productsEmpty,
                  actionLabel: l10n.productsAdd,
                  onAction: () => context.push(Routes.newProduct),
                );
              }
              return Column(
                children: [
                  if (items.isEmpty)
                    // A busca não achou: o cadastro continua à mão, e uma
                    // linha sozinha diria pouco sobre o porquê.
                    Padding(
                      padding: const EdgeInsets.only(bottom: BipaSpacing.s4),
                      child: Text(
                        l10n.productsNoMatch,
                        textAlign: TextAlign.center,
                        style: BipaText.body.copyWith(color: context.colors.inkMuted),
                      ),
                    ),
                  PriceRowList(rows: [for (final row in items) _row(context, l10n, row, now), addRow]),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  static PriceRowData _row(BuildContext context, AppLocalizations l10n, ProductRow row, DateTime now) {
    final price = row.price;
    return PriceRowData(
      icon: productCategoryIcon(row.product.name),
      title: row.product.name,
      meta: _meta(l10n, row),
      value: price?.price.format(),
      valueNote: _valueNote(l10n, row, now),
      onTap: () => context.push(Routes.productDetail(row.product.id)),
    );
  }

  /// "o kg" quando o preço é por unidade; e, a partir de 30 dias, a idade dele
  /// ("há 41 dias"), porque uma promoção velha não pode passar por preço de hoje
  /// (F5). Preço recente não ganha texto.
  static String? _valueNote(AppLocalizations l10n, ProductRow row, DateTime now) {
    final price = row.price;
    if (price == null) return null;
    final perUnit = price.perUnit;
    final days = calendarDaysSince(price.observedAt, now);
    final note = l10n.joinMeta([
      if (perUnit != null) l10n.productsPerUnit(perUnit.name),
      if (days >= priceStaleAfterDays) l10n.priceAge(days),
    ]);
    return note.isEmpty ? null : note;
  }

  /// A embalagem quando há uma ("União · 1 kg"), quantas são quando há
  /// várias, e "a granel" para o que se vende por quilo sem embalagem.
  static String? _meta(AppLocalizations l10n, ProductRow row) => switch (row.packages) {
    [] => row.product.unit == MeasureUnit.kilogram ? l10n.productsLoose : null,
    [final only] => only.label,
    final many => l10n.productsPackagesCount(many.length),
  };
}
