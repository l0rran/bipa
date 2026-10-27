import 'package:bipa/core/navigation/routes.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Estrutura com as abas principais e o atalho para bipar preços.
class HomeShell extends StatelessWidget {
  const HomeShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.capturePrice),
        icon: const Icon(Icons.document_scanner_outlined),
        label: const Text('Bipar preço'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          // Tocar na aba atual volta para o início dela.
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.kitchen_outlined),
            selectedIcon: Icon(Icons.kitchen),
            label: 'Estoque',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Produtos',
          ),
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: 'Mercados',
          ),
        ],
      ),
    );
  }
}
