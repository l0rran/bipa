import 'package:bipa/features/prices/domain/price_observation.dart';

/// Acesso ao histórico de preços.
abstract interface class PriceRepository {
  Future<void> add(PriceObservation observation);

  /// Grava todas ou nenhuma: os preços de uma etiqueta não ficam pela metade.
  Future<void> addAll(Iterable<PriceObservation> observations);

  /// Histórico do produto, do registro mais recente para o mais antigo.
  Stream<List<PriceHistoryEntry>> watchHistory(String productId);
}
