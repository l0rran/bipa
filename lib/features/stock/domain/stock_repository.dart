import 'package:bipa/features/stock/domain/stock_item.dart';
import 'package:bipa/features/stock/domain/stock_location.dart';
import 'package:bipa/features/stock/domain/stock_movement_reason.dart';

/// Acesso ao estoque da casa.
abstract interface class StockRepository {
  /// Itens em estoque com seus produtos, ordenados pelo nome do produto.
  Stream<List<StockEntry>> watchAll();

  Future<StockItem?> findByProduct(String productId);

  /// Soma [delta] à quantidade do produto (criando o item se necessário) e
  /// registra o movimento no histórico. A quantidade nunca fica negativa.
  Future<void> adjust({
    required String productId,
    required double delta,
    required StockMovementReason reason,
  });

  /// Define quanto a pessoa quer ter sempre em casa; `null` remove o alerta.
  Future<void> setTargetQuantity(String productId, double? target);

  Future<void> setLocation(String productId, StockLocation location);
}
