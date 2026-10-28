import 'package:bipa/features/prices/domain/price_observation.dart';

/// Acesso ao histórico de preços.
abstract interface class PriceRepository {
  Future<void> add(PriceObservation observation);

  /// Grava todas ou nenhuma: os preços de uma etiqueta não ficam pela metade.
  Future<void> addAll(Iterable<PriceObservation> observations);

  /// Histórico do produto, do registro mais recente para o mais antigo.
  Stream<List<PriceHistoryEntry>> watchHistory(String productId);

  /// Histórico de vários produtos de uma vez (por exemplo, os da lista de
  /// compras), do registro mais recente para o mais antigo.
  Stream<List<PriceHistoryEntry>> watchHistoryOfProducts(Set<String> productIds);

  /// Quando foi o preço mais recente de cada mercado, de qualquer produto:
  /// mostra se os preços dali estão em dia.
  Stream<Map<String, DateTime>> watchLatestPerMarket();
}
