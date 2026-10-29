/// Caminhos de navegação do app, centralizados para evitar strings soltas.
abstract final class Routes {
  // Abas principais.
  static const home = '/casa';
  static const products = '/produtos';
  static const markets = '/mercados';
  static const shoppingList = '/lista';

  // Telas em tela cheia (fora das abas).
  /// O leitor de código das buscas e do formulário do produto.
  static const scanner = '/scanner';

  /// A câmera do botão de bipar (protótipo "Captura").
  static const camera = '/camera';
  static const cartMode = '/carrinho';
  static const newProduct = '/produto/novo';
  static const newMarket = '/mercado/novo';

  /// O cadastro feito dentro do mercado (na escolha do mercado da compra):
  /// a localização atual é a dele.
  static const newMarketHere = '$newMarket?aqui=1';

  /// Registrar preço de um produto (pela tela dele): a câmera em "Etiqueta",
  /// com o produto esperando a etiqueta; com [packageId], daquela embalagem.
  static String cameraPriceFor(String productId, {String? packageId}) => Uri(
    path: camera,
    queryParameters: {'modo': 'etiqueta', 'produto': productId, 'embalagem': ?packageId},
  ).toString();

  /// A câmera em "Código": o produto bipado abre (a busca da aba Produtos).
  static const cameraFind = '$camera?modo=codigo';

  /// A câmera somando em casa cada código ("Comprei", o Início vazio).
  static const cameraBought = '$camera?modo=comprei';

  /// A câmera dando baixa em casa ("Dar baixa em casa", no menu do bipar).
  static const cameraUsed = '$camera?modo=usei';

  static String productDetail(String id) => '/produto/$id';

  static String editProduct(String id) => '/produto/$id/editar';

  static String market(String id) => '/mercado/$id';

  static String editMarket(String id) => '/mercado/$id/editar';
}
