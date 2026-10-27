import 'package:bipa/core/design_system/components/scan_nav_bar.dart';
import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/core/navigation/routes.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Estrutura com as abas principais e o botão de bipar no centro da barra.
class HomeShell extends StatelessWidget {
  const HomeShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      // O conteúdo passa por trás da barra de vidro.
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: ScanNavBar(
        selectedIndex: navigationShell.currentIndex,
        onSelected: (index) => navigationShell.goBranch(
          index,
          // Tocar na aba atual volta para o início dela.
          initialLocation: index == navigationShell.currentIndex,
        ),
        onScan: () => context.push(Routes.capturePrice),
        scanLabel: l10n.navScan,
        // A ordem segue os ramos do StatefulShellRoute em router.dart.
        destinations: [
          ScanNavDestination(icon: Icons.home_outlined, selectedIcon: Icons.home_rounded, label: l10n.navHome),
          ScanNavDestination(icon: Icons.sell_outlined, selectedIcon: Icons.sell_rounded, label: l10n.navProducts),
          ScanNavDestination(icon: Icons.place_outlined, selectedIcon: Icons.place_rounded, label: l10n.navMarkets),
          ScanNavDestination(icon: Icons.checklist_outlined, selectedIcon: Icons.checklist_rounded, label: l10n.navList),
        ],
      ),
    );
  }
}
