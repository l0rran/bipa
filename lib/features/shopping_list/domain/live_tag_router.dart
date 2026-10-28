import 'package:bipa/features/shopping_list/domain/cart_item.dart';
import 'package:bipa/features/shopping_list/domain/live_scan.dart';
import 'package:meta/meta.dart';

/// Um preço lido ao vivo que ainda não achou o seu item.
@immutable
final class PendingTagPrice {
  const PendingTagPrice({required this.read, required this.readAt, this.productId, this.barcode});

  final TagPriceRead read;
  final DateTime readAt;

  /// O produto da etiqueta, quando o código dela é conhecido: só ele leva o
  /// preço.
  final String? productId;

  /// O código da etiqueta, quando ele ainda não é de nenhum produto: só o
  /// produto cadastrado com ele leva o preço.
  final String? barcode;

  @override
  bool operator ==(Object other) =>
      other is PendingTagPrice &&
      other.read == read &&
      other.readAt == readAt &&
      other.productId == productId &&
      other.barcode == barcode;

  @override
  int get hashCode => Object.hash(read, readAt, productId, barcode);

  @override
  String toString() => 'PendingTagPrice($read, $readAt, $productId, $barcode)';
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
/// 1. Etiqueta com o código de um produto conhecido: o preço é desse
///    produto. Se ele ainda não está no carrinho, espera ser bipado, sem
///    entrar sozinho.
/// 2. Etiqueta com um código que nenhum produto tem: espera o produto ser
///    cadastrado e bipado com esse código.
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
  /// entrega. [settled] são os itens com o preço já firmado: lido ao vivo,
  /// digitado ou fotografado. O preço esperado, vindo do histórico, não
  /// firma o item.
  LiveTagDestination route(
    TagPriceRead read, {
    required List<CartEntry> cart,
    required DateTime now,
    String? tagProductId,
    Set<String> settled = const {},
  }) {
    if (tagProductId != null) {
      final entry = cart.where((entry) => entry.product.id == tagProductId).firstOrNull;
      return entry != null
          ? PriceCartItem(entry)
          : WaitForProduct(PendingTagPrice(read: read, readAt: now, productId: tagProductId));
    }
    final barcode = read.barcode;
    if (barcode != null) return WaitForProduct(PendingTagPrice(read: read, readAt: now, barcode: barcode));

    final newest = cart.firstOrNull;
    if (newest != null &&
        !settled.contains(newest.item.id) &&
        now.difference(newest.item.addedAt) <= recent) {
      return PriceCartItem(newest);
    }
    return WaitForProduct(PendingTagPrice(read: read, readAt: now));
  }

  /// Se o preço que espera vale para o produto que acabou de ser bipado com
  /// [barcode].
  bool fits(PendingTagPrice pending, {required String productId, required String barcode, required DateTime now}) {
    if (now.difference(pending.readAt) > waitFor) return false;
    if (pending.productId case final expected?) return expected == productId;
    if (pending.barcode case final expected?) return expected == barcode;
    return true;
  }
}
