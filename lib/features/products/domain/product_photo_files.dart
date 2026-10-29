/// Os arquivos das fotos dos produtos (ADR 0010), guardados fora do banco.
/// O produto só guarda o caminho relativo (`Product.photoPath`).
abstract interface class ProductPhotoFiles {
  /// Apaga a foto do [photoPath]. Uma foto que já não existe não é erro.
  Future<void> delete(String photoPath);
}
