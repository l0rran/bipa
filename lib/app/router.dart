import 'package:bipa/app/home_shell.dart';
import 'package:bipa/core/navigation/routes.dart';
import 'package:bipa/features/markets/presentation/market_form_page.dart';
import 'package:bipa/features/markets/presentation/market_page.dart';
import 'package:bipa/features/markets/presentation/markets_page.dart';
import 'package:bipa/features/prices/presentation/camera_page.dart';
import 'package:bipa/features/products/presentation/product_detail_page.dart';
import 'package:bipa/features/products/presentation/product_form_page.dart';
import 'package:bipa/features/products/presentation/products_page.dart';
import 'package:bipa/features/products/presentation/scan_code_page.dart';
import 'package:bipa/features/settings/presentation/settings_page.dart';
import 'package:bipa/features/shopping_list/presentation/cart_mode_page.dart';
import 'package:bipa/features/shopping_list/presentation/shopping_list_page.dart';
import 'package:bipa/features/stock/presentation/home_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: Routes.home,
    routes: [
      // Abas: cada uma mantém sua própria pilha de navegação.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => HomeShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.home, builder: (_, _) => const HomePage())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.products, builder: (_, _) => const ProductsPage())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.markets, builder: (_, _) => const MarketsPage())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.shoppingList, builder: (_, _) => const ShoppingListPage())],
          ),
        ],
      ),

      // Telas em tela cheia, sobre as abas.
      GoRoute(path: Routes.scanner, builder: (_, _) => const ScanCodePage()),
      GoRoute(path: Routes.cartMode, builder: (_, _) => const CartModePage()),
      GoRoute(path: Routes.settings, builder: (_, _) => const SettingsPage()),
      GoRoute(
        path: Routes.camera,
        builder: (_, state) => CameraPage(
          mode: CameraMode.fromQuery(state.uri.queryParameters['modo']),
          productId: state.uri.queryParameters['produto'],
          packageId: state.uri.queryParameters['embalagem'],
        ),
      ),
      // "/produto/novo" precisa vir antes de "/produto/:id".
      GoRoute(
        path: Routes.newProduct,
        builder: (_, state) => ProductFormPage(
          args: switch (state.extra) {
            final ProductFormArgs args => args,
            _ => const ProductFormArgs(),
          },
        ),
      ),
      GoRoute(
        path: '/produto/:id/editar',
        builder: (_, state) => ProductFormPage(productId: state.pathParameters['id']),
      ),
      GoRoute(
        path: '/produto/:id',
        builder: (_, state) => ProductDetailPage(productId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.newMarket,
        builder: (_, state) => MarketFormPage(here: state.uri.queryParameters['aqui'] == '1'),
      ),
      GoRoute(
        path: '/mercado/:id/editar',
        builder: (_, state) => MarketFormPage(marketId: state.pathParameters['id']),
      ),
      // Depois de "/mercado/novo", que senão viraria um mercado de id "novo".
      GoRoute(
        path: '/mercado/:id',
        builder: (_, state) => MarketPage(marketId: state.pathParameters['id']!),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
