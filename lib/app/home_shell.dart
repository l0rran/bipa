import 'package:bipa/core/design_system/bipa_metrics.dart';
import 'package:bipa/core/design_system/components/scan_nav_bar.dart';
import 'package:bipa/core/design_system/components/shopping_list.dart';
import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/core/navigation/routes.dart';
import 'package:bipa/features/shopping_list/presentation/shopping_list_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Estrutura com as abas principais e o botão de bipar no centro da barra.
///
/// Durante uma compra, a barra da compra fica acima da navegação em todas as
/// abas, menos na Lista, que já mostra o mesmo progresso.
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
                title: l10n.tripItems(summary.done, summary.total),
                subtitle: _subtitle(summary.spent?.format(), marketName),
                actionLabel: l10n.tripContinue,
                progress: summary.progress,
                semanticLabel: l10n.tripSemantics(summary.done, summary.total),
                onTap: () => goBranch(_listBranch),
              ),
            ),
          ScanNavBar(
            selectedIndex: navigationShell.currentIndex,
            onSelected: goBranch,
            onScan: () => context.push(Routes.capturePrice),
            scanLabel: l10n.navScan,
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

  /// "R$ 32,10 · Atacarejo Vila Nova": o total do carrinho e o mercado.
  static String? _subtitle(String? spent, String? marketName) {
    final parts = [?spent, ?marketName];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}
