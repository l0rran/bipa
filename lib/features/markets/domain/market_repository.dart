import 'package:bipa/features/markets/domain/market.dart';

/// Acesso aos mercados cadastrados.
abstract interface class MarketRepository {
  /// Mercados ordenados por nome.
  Stream<List<Market>> watchAll();

  Future<List<Market>> all();

  Future<Market?> findById(String id);

  /// Cria ou atualiza o mercado.
  Future<void> save(Market market);

  /// Apaga o mercado e, junto, os preços e a ordem das seções dele; as
  /// compras feitas nele ficam sem mercado (ADR 0016).
  Future<void> delete(String id);
}
