import 'package:bipa/features/prices/domain/price_observation.dart';

/// Acesso ao histórico de preços.
abstract interface class PriceRepository {
  Future<void> add(PriceObservation observation);

  /// Histórico do produto, do registro mais recente para o mais antigo.
  Stream<List<PriceHistoryEntry>> watchHistory(String productId);
}
