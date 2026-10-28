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
/// modo carrinho.
class HomeShell extends ConsumerWidget {
  const HomeShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  // A ordem segue os ramos do StatefulShellRoute em router.dart.
  static const _listBranch = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final trip = ref.watch(shoppingTripSummaryProvider);
    final marketName = ref.watch(activeTripMarketNameProvider);

    void goBranch(int index) => navigationShell.goBranch(
      index,
      // Tocar na aba atual volta para o início dela.
      initialLocation: index == navigationShell.currentIndex,
    );

    return Scaffold(
      // O conteúdo passa por trás das barras; as telas usam o
      // MediaQuery.padding.bottom para deixar espaço embaixo.
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trip case final summary? when navigationShell.currentIndex != _listBranch)
            Padding(
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
              ),
            ),
          ScanNavBar(
            selectedIndex: navigationShell.currentIndex,
            onSelected: goBranch,
            // Durante a compra, bipar é o modo carrinho; fora dela, a câmera.
            onScan: () => context.push(trip == null ? Routes.camera : Routes.cartMode),
            scanLabel: l10n.navScan,
            onScanLongPress: () => _openScanMenu(context, ref, shopping: trip != null),
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
        ],
      ),
    );
  }

  /// Segurar o bipar: o modo carrinho, guardar em casa o que chegou ou dar
  /// baixa em casa.
  static Future<void> _openScanMenu(BuildContext context, WidgetRef ref, {required bool shopping}) async {
    final l10n = AppLocalizations.of(context);
    final choice = await showScanMenu<_ScanAction>(
      context,
      closeLabel: l10n.scanMenuClose,
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
