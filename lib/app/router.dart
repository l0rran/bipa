import 'package:bipa/app/home_shell.dart';
import 'package:bipa/core/navigation/routes.dart';
import 'package:bipa/features/markets/presentation/market_form_page.dart';
import 'package:bipa/features/markets/presentation/markets_page.dart';
import 'package:bipa/features/prices/presentation/capture_price_page.dart';
import 'package:bipa/features/products/presentation/barcode_scanner_page.dart';
import 'package:bipa/features/products/presentation/product_detail_page.dart';
import 'package:bipa/features/products/presentation/product_form_page.dart';
import 'package:bipa/features/products/presentation/products_page.dart';
import 'package:bipa/features/stock/presentation/stock_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: Routes.stock,
    routes: [
      // Abas: cada uma mantém sua própria pilha de navegação.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => HomeShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.stock, builder: (_, _) => const StockPage())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.products, builder: (_, _) => const ProductsPage())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.markets, builder: (_, _) => const MarketsPage())],
          ),
        ],
      ),

      // Telas em tela cheia, sobre as abas.
      GoRoute(path: Routes.scanner, builder: (_, _) => const BarcodeScannerPage()),
      GoRoute(
        path: Routes.capturePrice,
        builder: (_, state) => CapturePricePage(productId: state.uri.queryParameters['produto']),
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
      GoRoute(path: Routes.newMarket, builder: (_, _) => const MarketFormPage()),
      GoRoute(
        path: '/mercado/:id/editar',
        builder: (_, state) => MarketFormPage(marketId: state.pathParameters['id']),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
