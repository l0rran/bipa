import 'package:bipa/features/stock/domain/stock_item.dart';

/// Os produtos que entraram em casa numa sessão da câmera de "Guardar em
/// casa" sem estarem lá antes, para a folha "Arrumar o que entrou" (AB5).
///
/// Um item que nasce no bipe fica no local sugerido pela categoria (ou no
/// lembrado, ADR 0021) e sem "ter sempre". O aviso do visor deixa trocar o
/// local na hora (AB9); o item cujo local a pessoa escolheu ali já foi
/// conferido. A folha junta, ao fechar a câmera, só os que ninguém conferiu,
/// sem mínimo: com um só, ela aparece; sem nenhum, a câmera fecha direto
/// (AB13, proposta A do quadro "ArrumarEntrouRegra").
final class HomeArrivals {
  /// Na ordem em que entraram; o mesmo produto conta uma vez.
  final _productIds = <String>{};

  /// Os produtos cujo local a pessoa escolheu no aviso da câmera.
  final _checked = <String>{};

  /// O produto entrou em casa neste bipe, e não estava lá antes. Se ele
  /// nasce de novo, o local é sugerido de novo e volta a não estar conferido.
  void entered(String productId) {
    _productIds.add(productId);
    _checked.remove(productId);
  }

  /// A pessoa escolheu o local do produto no aviso da câmera (mesmo que
  /// tenha mantido o sugerido): ele sai da folha.
  void placeChosen(String productId) {
    if (_productIds.contains(productId)) _checked.add(productId);
  }

  /// Os produtos que entraram, na ordem do primeiro bipe.
  List<String> get productIds => List.unmodifiable(_productIds);

  /// Se fechar a câmera pode passar pela folha: algum produto novo ainda não
  /// foi conferido. Quem decide se ela abre de fato é [toArrange], que olha
  /// o estoque.
  bool get mayArrange => _productIds.any((id) => !_checked.contains(id));

  /// O que a folha mostra ao fechar a câmera, na ordem em que entrou: os
  /// produtos novos que continuam em casa ([atHome], o estoque de agora) e
  /// cujo local ninguém escolheu no aviso. Vazio, a folha não abre.
  ///
  /// Um bipe desfeito deixa o item com zero: ele não entrou de fato e não
  /// conta. Um produto apagado (ou juntado a outro) nesse meio-tempo some do
  /// estoque e também não conta.
  List<String> toArrange(Iterable<StockItem> atHome) {
    final present = {
      for (final item in atHome)
        if (!item.isOut) item.productId,
    };
    return [
      for (final id in _productIds)
        if (present.contains(id) && !_checked.contains(id)) id,
    ];
  }
}
