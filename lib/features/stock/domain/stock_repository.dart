import 'package:bipa/features/stock/domain/stock_item.dart';
import 'package:bipa/features/stock/domain/stock_location.dart';
import 'package:bipa/features/stock/domain/stock_movement_reason.dart';
import 'package:bipa/features/stock/domain/stock_package.dart';

/// Acesso ao estoque da casa.
abstract interface class StockRepository {
  /// Itens em estoque com seus produtos, ordenados pelo nome do produto.
  Stream<List<StockEntry>> watchAll();

  Future<StockItem?> findByProduct(String productId);

  /// Soma [delta] à quantidade do produto (criando o item se necessário) e
  /// registra o movimento no histórico. A quantidade nunca fica negativa.
  ///
  /// As embalagens acompanham (ADR 0013): o que entra vai para [packageId]
  /// ou, sem ela, para a embalagem mais nova do produto; o que sai sai de
  /// [packageId] e depois da embalagem que está em casa há mais tempo.
  Future<void> adjust({
    required String productId,
    required double delta,
    required StockMovementReason reason,
    String? packageId,
  });

  /// Quantas embalagens de cada tipo há em casa, da que entrou primeiro para
  /// a mais recente.
  Stream<List<StockPackageCount>> watchPackages(String productId);

  /// Define quanto a pessoa quer ter sempre em casa; `null` remove o alerta.
  Future<void> setTargetQuantity(String productId, double? target);

  Future<void> setLocation(String productId, StockLocation location);
}
