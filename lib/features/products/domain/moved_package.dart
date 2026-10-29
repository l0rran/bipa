import 'package:meta/meta.dart';

/// O que "Mover embalagem…" fez (ADR 0022), o bastante para o "Desfazer"
/// levar a embalagem de volta e tirar o que nasceu só por causa da movida.
@immutable
final class MovedPackage {
  const MovedPackage({
    required this.packageId,
    required this.fromProductId,
    required this.intoProductId,
    this.createdStockItem = false,
  });

  final String packageId;

  /// O produto de onde a embalagem saiu.
  final String fromProductId;

  /// O produto que ficou com ela.
  final String intoProductId;

  /// O destino não estava em casa e ganhou um item de estoque por causa da
  /// movida. Se, ao desfazer, ele voltar a zero, sai de novo.
  final bool createdStockItem;
}
