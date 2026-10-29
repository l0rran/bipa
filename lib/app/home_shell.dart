import 'package:bipa/core/design_system/bipa_metrics.dart';
import 'package:bipa/core/design_system/components/scan_menu.dart';
import 'package:bipa/core/design_system/components/scan_nav_bar.dart';
import 'package:bipa/core/design_system/components/shopping_list.dart';
import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/core/l10n/meta_join.dart';
import 'package:bipa/core/navigation/routes.dart';
import 'package:bipa/features/shopping_list/domain/shopping_trip.dart';
import 'package:bipa/features/shopping_list/presentation/shopping_list_providers.dart';
import 'package:bipa/features/shopping_list/presentation/start_shopping.dart';
import 'package:bipa/features/shopping_list/presentation/trip_summary_label.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Estrutura com as abas principais e o botão de bipar no centro da barra.
///
/// Durante uma compra, a barra da compra fica acima da navegação em todas as
/// abas, menos na Lista, que já mostra o mesmo progresso. "Continuar" abre o
/// modo carrinho. Com a letra acima de 160%, ela fica no lugar do bipar
/// flutuante, que sai, e segurá-la abre o menu do bipar (H12).
///
/// Rolando o conteúdo de qualquer aba para baixo, a barra encolhe; para cima,
/// no topo ou ao trocar de aba, ela volta ao normal. Com a letra a partir de
/// 130% ou com o TalkBack, ela não encolhe, e acima de 160% o bipar flutua
/// acima da barra (`ScanNavBar`).
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  // A ordem segue os ramos do StatefulShellRoute em router.dart.
  static const _listBranch = 3;

  final _compact = ScanNavBarCompactController();

  @override
  void didUpdateWidget(HomeShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A aba mudou por fora da barra (um link, por exemplo): a barra volta.
    if (widget.navigationShell.currentIndex != oldWidget.navigationShell.currentIndex) _compact.expand();
  }

  @override
  void dispose() {
    _compact.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final trip = ref.watch(shoppingTripSummaryProvider);
    final marketName = ref.watch(activeTripMarketNameProvider);
    final navigationShell = widget.navigationShell;
    // Com o bipar flutuante, a barra da compra assume o toque longo dele.
    final floatingScan = ScanNavBar.floatsScan(context);

    void goBranch(int index) {
      _compact.expand();
      navigationShell.goBranch(
        index,
        // Tocar na aba atual volta para o início dela.
        initialLocation: index == navigationShell.currentIndex,
      );
    }

    return Scaffold(
      // O conteúdo passa por trás das barras; as telas usam o
      // MediaQuery.padding.bottom para deixar espaço embaixo. A barra ocupa
      // sempre a altura da normal, então o conteúdo não fica escondido atrás
      // dela em nenhum dos dois tamanhos; com o bipar flutuante, a altura
      // inclui o botão.
      extendBody: true,
      // A rolagem de todas as abas passa por aqui, sem mexer em cada tela.
      body: NotificationListener<ScrollMetricsNotification>(
        onNotification: _compact.onScrollMetricsNotification,
        child: NotificationListener<ScrollNotification>(
          onNotification: _compact.onScrollNotification,
          child: navigationShell,
        ),
      ),
      bottomNavigationBar: ValueListenableBuilder(
        valueListenable: _compact,
        builder: (context, compact, _) => ScanNavBar(
          compact: compact,
          // A barra da compra desce junto quando a navegação encolhe.
          above: switch (trip) {
            final summary? when navigationShell.currentIndex != _listBranch => Padding(
              padding: const EdgeInsets.fromLTRB(BipaSpacing.s3, 0, BipaSpacing.s3, BipaSpacing.s2),
              child: ShoppingBar(
                title: _title(l10n, summary),
                subtitle: _subtitle(l10n, summary.spentLabel(l10n), marketName),
                actionLabel: l10n.tripContinue,
                // Sem lista não há progresso: o fio sai.
                progress: summary.hasList ? summary.progress : null,
                // O leitor de tela ouve o mesmo que a tela mostra.
                semanticLabel: l10n.tripSemantics(
                  l10n.joinMeta([_title(l10n, summary), ?_subtitle(l10n, summary.spentLabel(l10n), marketName)]),
                ),
                // "Continuar" volta para o modo carrinho.
                onTap: () => context.push(Routes.cartMode),
                // Acima de 160%, o bipar flutuante sai e a barra fica no
                // lugar dele: segurar abre o menu, ancorado nela.
                onLongPress: floatingScan
                    ? (barRect) {
                        _openScanMenu(context, ref, shopping: true, anchor: barRect);
                      }
                    : null,
                longPressHint: l10n.navScanMore,
              ),
            ),
            _ => null,
          },
          aboveReplacesScan: true,
          selectedIndex: navigationShell.currentIndex,
          onSelected: goBranch,
          // Durante a compra, bipar é o modo carrinho; fora dela, a câmera.
          onScan: () => context.push(trip == null ? Routes.camera : Routes.cartMode),
          scanLabel: l10n.navScan,
          onScanLongPress: (scanRect) {
            // O "×" do menu fica no lugar do botão da barra normal, ou do
            // bipar flutuante com letra grande.
            _compact.expand();
            _openScanMenu(context, ref, shopping: trip != null, anchor: scanRect);
          },
          scanLongPressLabel: l10n.navScanMore,
          destinations: [
            ScanNavDestination(icon: Icons.home_outlined, selectedIcon: Icons.home_rounded, label: l10n.navHome),
            ScanNavDestination(icon: Icons.sell_outlined, selectedIcon: Icons.sell_rounded, label: l10n.navProducts),
            ScanNavDestination(icon: Icons.place_outlined, selectedIcon: Icons.place_rounded, label: l10n.navMarkets),
            ScanNavDestination(
              icon: Icons.checklist_outlined,
              selectedIcon: Icons.checklist_rounded,
              label: l10n.navList,
            ),
          ],
        ),
      ),
    );
  }

  /// Segurar o bipar: o modo carrinho, guardar em casa o que chegou ou dar
  /// baixa em casa.
  static Future<void> _openScanMenu(
    BuildContext context,
    WidgetRef ref, {
    required bool shopping,
    required Rect anchor,
  }) async {
    final l10n = AppLocalizations.of(context);
    final choice = await showScanMenu<_ScanAction>(
      context,
      closeLabel: l10n.scanMenuClose,
      anchor: anchor,
      items: [
        (
          value: _ScanAction.cart,
          icon: Icons.shopping_cart_outlined,
          label: l10n.scanMenuCart,
          hint: l10n.scanMenuCartHint,
        ),
        (value: _ScanAction.bought, icon: Icons.add_home_outlined, label: l10n.scanMenuBought, hint: null),
        (value: _ScanAction.used, icon: Icons.home_outlined, label: l10n.scanMenuUsed, hint: null),
      ],
    );
    if (!context.mounted) return;
    switch (choice) {
      case _ScanAction.cart when shopping:
        await context.push(Routes.cartMode);
      case _ScanAction.cart:
        await startShopping(context, ref);
      case _ScanAction.bought:
        await context.push(Routes.cameraBought);
      case _ScanAction.used:
        await context.push(Routes.cameraUsed);
      case null:
        break;
    }
  }

  /// "3 de 7 itens"; numa compra sem lista, "8 no carrinho".
  static String _title(AppLocalizations l10n, ShoppingTripSummary summary) =>
      summary.hasList ? l10n.tripItems(summary.done, summary.total) : l10n.tripInCart(summary.packages);

  /// "R$ 32,10 · Atacarejo Vila Nova": o total do carrinho e o mercado.
  static String? _subtitle(AppLocalizations l10n, String? spent, String? marketName) {
    final parts = [?spent, ?marketName];
    return parts.isEmpty ? null : l10n.joinMeta(parts);
  }
}

/// As opções do menu do bipar.
enum _ScanAction { cart, bought, used }
