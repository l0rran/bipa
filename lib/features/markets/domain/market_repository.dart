import 'package:bipa/features/markets/domain/market.dart';

/// Acesso aos mercados cadastrados.
abstract interface class MarketRepository {
  /// Mercados ordenados por nome.
  Stream<List<Market>> watchAll();

  Future<List<Market>> all();

  Future<Market?> findById(String id);

  /// Cria ou atualiza o mercado.
  Future<void> save(Market market);
}
