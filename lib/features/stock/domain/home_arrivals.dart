import 'package:bipa/features/stock/domain/stock_item.dart';

/// Os produtos que entraram em casa numa sessão da câmera de "Guardar em
/// casa" sem estarem lá antes, para a folha "Arrumar o que entrou" (AB5).
///
/// Um item que nasce no bipe fica no local sugerido pela categoria (ou no
/// lembrado, ADR 0021) e sem "ter sempre". Com poucos itens, o aviso do
/// visor já deixa trocar o local (AB9); a partir de [minimumToArrange], a
/// folha junta todos ao fechar a câmera, para acertar de uma vez.
final class HomeArrivals {
  /// Quantos produtos novos fazem a folha aparecer.
  static const minimumToArrange = 3;

  /// Na ordem em que entraram; o mesmo produto conta uma vez.
  final _productIds = <String>{};

  /// O produto entrou em casa neste bipe, e não estava lá antes.
  void entered(String productId) => _productIds.add(productId);

  /// Os produtos que entraram, na ordem do primeiro bipe.
  List<String> get productIds => List.unmodifiable(_productIds);

  /// O que a folha mostra ao fechar a câmera, na ordem em que entrou: os
  /// produtos novos que continuam em casa ([atHome], o estoque de agora),
  /// ou nada, se forem menos de [minimumToArrange].
  ///
  /// Um bipe desfeito deixa o item com zero: ele não entrou de fato e não
  /// conta. Um produto apagado (ou juntado a outro) nesse meio-tempo some do
  /// estoque e também não conta.
  List<String> toArrange(Iterable<StockItem> atHome) {
    final present = {
      for (final item in atHome)
        if (!item.isOut) item.productId,
    };
    final arrived = [
      for (final id in _productIds)
        if (present.contains(id)) id,
    ];
    return arrived.length >= minimumToArrange ? arrived : const [];
  }
}
