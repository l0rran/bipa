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

  /// A câmera do botão de bipar (protótipo "Captura").
  static const camera = '/camera';
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

  /// O formulário do preço, já abrindo a câmera para fotografar a etiqueta.
  static const capturePricePhoto = '$capturePrice?foto=1';

  /// A câmera somando em casa cada código ("Comprei", o Início vazio).
  static const cameraBought = '$camera?modo=comprei';

  /// A câmera dando baixa em casa ("Dar baixa em casa", no menu do bipar).
  static const cameraUsed = '$camera?modo=usei';

  static String productDetail(String id) => '/produto/$id';

  static String editProduct(String id) => '/produto/$id/editar';

  static String market(String id) => '/mercado/$id';

  static String editMarket(String id) => '/mercado/$id/editar';
}
