import 'package:bipa/core/catalog/product_kind.dart';
import 'package:bipa/features/shopping_list/domain/cart_item.dart';
import 'package:bipa/features/shopping_list/domain/live_scan.dart';
import 'package:meta/meta.dart';

/// Um preço lido ao vivo que ainda não achou o seu item.
@immutable
final class PendingTagPrice {
  const PendingTagPrice({required this.read, required this.readAt, this.barcode});

  final TagPriceRead read;
  final DateTime readAt;

  /// O código da etiqueta, quando ela tinha um: só a embalagem com esse
  /// código leva o preço.
  final String? barcode;

  @override
  bool operator ==(Object other) =>
      other is PendingTagPrice && other.read == read && other.readAt == readAt && other.barcode == barcode;

  @override
  int get hashCode => Object.hash(read, readAt, barcode);

  @override
  String toString() => 'PendingTagPrice($read, $readAt, $barcode)';
}

/// Para onde vai um preço lido ao vivo.
sealed class LiveTagDestination {
  const LiveTagDestination();
}

/// O preço vai para um item que já está no carrinho.
final class PriceCartItem extends LiveTagDestination {
  const PriceCartItem(this.entry);

  final CartEntry entry;

  @override
  bool operator ==(Object other) => other is PriceCartItem && other.entry == entry;

  @override
  int get hashCode => entry.hashCode;

  @override
  String toString() => 'PriceCartItem(${entry.item.id})';
}

/// O preço espera o próximo produto bipado.
final class WaitForProduct extends LiveTagDestination {
  const WaitForProduct(this.pending);

  final PendingTagPrice pending;

  @override
  bool operator ==(Object other) => other is WaitForProduct && other.pending == pending;

  @override
  int get hashCode => pending.hashCode;

  @override
  String toString() => 'WaitForProduct($pending)';
}

/// Decide a que item vai o preço de uma etiqueta lida ao vivo (ADR 0012).
///
/// 1. Etiqueta com o código de uma embalagem conhecida: o preço é dessa
///    embalagem (ADR 0013). Se ela ainda não está no carrinho, espera ser
///    bipada, sem entrar sozinha.
/// 2. Etiqueta com um código que nenhuma embalagem tem: espera a embalagem
///    ser cadastrada e bipada com esse código.
/// 3. Sem código: vai para o último item bipado, se ele entrou há até
///    [recent] e o preço dele ainda não foi firmado (lido ao vivo, digitado
///    ou fotografado). Assim, a etiqueta do lado, lida logo depois, não
///    sobrescreve o preço certo.
/// 4. Senão, espera o próximo produto bipado por até [waitFor].
final class LiveTagRouter {
  const LiveTagRouter({this.recent = const Duration(seconds: 20), this.waitFor = const Duration(seconds: 20)});

  final Duration recent;
  final Duration waitFor;

  /// [cart] vem do mais recente para o mais antigo, como o repositório
  /// entrega. [tagPackageId] é a embalagem do código da etiqueta, quando ele
  /// é conhecido. [settled] são os itens com o preço já firmado: lido ao
  /// vivo, digitado ou fotografado. O preço esperado, vindo do histórico, não
  /// firma o item.
  LiveTagDestination route(
    TagPriceRead read, {
    required List<CartEntry> cart,
    required DateTime now,
    String? tagPackageId,
    Set<String> settled = const {},
  }) {
    final barcode = read.barcode;
    if (tagPackageId != null) {
      final entry = cart.where((entry) => entry.item.packageId == tagPackageId).firstOrNull;
      if (entry != null) return PriceCartItem(entry);
    }
    if (barcode != null) return WaitForProduct(PendingTagPrice(read: read, readAt: now, barcode: barcode));

    final newest = cart.firstOrNull;
    if (newest != null &&
        !settled.contains(newest.item.id) &&
        now.difference(newest.item.addedAt) <= recent) {
      return PriceCartItem(newest);
    }
    return WaitForProduct(PendingTagPrice(read: read, readAt: now));
  }

  /// Se o preço que espera vale para a embalagem que acabou de ser bipada
  /// (ou cadastrada) com [barcode]: a etiqueta não tinha código ou tinha
  /// esse mesmo.
  ///
  /// Uma etiqueta sem código que trouxe o nome ("ARROZ BRANCO TIO JOAO")
  /// não vale para um produto de outra seção ([productName] "Detergente"):
  /// a pessoa desistiu daquele e bipou outro.
  bool fits(PendingTagPrice pending, {required String barcode, required DateTime now, String? productName}) {
    if (now.difference(pending.readAt) > waitFor) return false;
    if (pending.barcode != null) return pending.barcode == barcode;
    return productName == null || _sameAisle(pending.read.nameHint, productName);
  }

  /// "Outros" não decide nada: pode ser qualquer coisa.
  static bool _sameAisle(String? hint, String productName) {
    if (hint == null) return true;
    final tag = ProductKind.of(hint).aisle;
    final product = ProductKind.of(productName).aisle;
    return tag == Aisle.other || product == Aisle.other || tag == product;
  }
}
