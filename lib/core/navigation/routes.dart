/// Caminhos de navegação do app, centralizados para evitar strings soltas.
abstract final class Routes {
  // Abas principais.
  static const home = '/casa';
  static const products = '/produtos';
  static const markets = '/mercados';
  static const shoppingList = '/lista';

  // Telas em tela cheia (fora das abas).
  static const scanner = '/scanner';
  static const capturePrice = '/bipar';
  static const newProduct = '/produto/novo';
  static const newMarket = '/mercado/novo';

  static String capturePriceFor(String productId) => '$capturePrice?produto=$productId';

  static String productDetail(String id) => '/produto/$id';

  static String editProduct(String id) => '/produto/$id/editar';

  static String editMarket(String id) => '/mercado/$id/editar';
}
