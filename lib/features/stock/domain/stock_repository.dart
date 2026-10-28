import 'package:bipa/features/stock/domain/stock_item.dart';
import 'package:bipa/features/stock/domain/stock_location.dart';
import 'package:bipa/features/stock/domain/stock_movement_reason.dart';
import 'package:bipa/features/stock/domain/stock_lot.dart';

/// Acesso ao estoque da casa.
abstract interface class StockRepository {
  /// Itens em estoque com seus produtos, ordenados pelo nome do produto.
  Stream<List<StockEntry>> watchAll();

  Future<StockItem?> findByProduct(String productId);

  /// Soma [delta] à quantidade do produto (criando o item se necessário) e
  /// registra o movimento no histórico. A quantidade nunca fica negativa.
  ///
  /// Os lotes acompanham (ADR 0013): o que entra vira um lote de
  /// [packageId] ou, sem ela, da embalagem mais nova do produto; o que sai
  /// sai dos lotes de [packageId] e depois do lote mais antigo.
  ///
  /// Devolve o que mudou de fato, para o [revert].
  Future<StockChange> adjust({
    required String productId,
    required double delta,
    required StockMovementReason reason,
    String? packageId,
  });

  /// Desfaz um [adjust]: tira o lote que entrou e devolve os que saíram. Se
  /// parte do que entrou já foi usada, tira o resto dos lotes mais antigos.
  Future<void> revert(StockChange change);

  /// Os lotes em casa, do que entrou primeiro para o mais recente, com as
  /// embalagens.
  Stream<List<StockLot>> watchLots(String productId);

  /// Tira o produto de casa: o item e os lotes somem (o histórico de
  /// movimentos fica). O produto e os preços continuam.
  Future<void> remove(String productId);

  /// Define quanto a pessoa quer ter sempre em casa; `null` remove o alerta.
  Future<void> setTargetQuantity(String productId, double? target);

  Future<void> setLocation(String productId, StockLocation location);
}
