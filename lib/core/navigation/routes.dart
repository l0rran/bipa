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
  static const cartMode = '/carrinho';
  static const newProduct = '/produto/novo';
  static const newMarket = '/mercado/novo';

  /// O cadastro feito dentro do mercado (na escolha do mercado da compra):
  /// a localização atual é a dele.
  static const newMarketHere = '$newMarket?aqui=1';

  /// Registrar preço de um produto; com [packageId], daquela embalagem.
  static String capturePriceFor(String productId, {String? packageId}) =>
      Uri(path: capturePrice, queryParameters: {'produto': productId, 'embalagem': ?packageId}).toString();

  /// A foto da etiqueta aberta pelo modo carrinho.
  static const capturePriceFromCart = '$capturePrice?carrinho=1';

  static String productDetail(String id) => '/produto/$id';

  static String editProduct(String id) => '/produto/$id/editar';

  static String editMarket(String id) => '/mercado/$id/editar';
}
