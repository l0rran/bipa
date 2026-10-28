import 'package:meta/meta.dart';

/// Para quem e em que quantidade um preço vale (ADR 0011).
///
/// Etiquetas de atacarejo trazem até três preços: varejo ([AnyCustomer]),
/// cartão da loja ([LoyaltyMembers]) e atacado ([Wholesale]).
@immutable
sealed class PriceCondition {
  const PriceCondition();

  /// Tipo gravado no banco, sem os dados extras da condição.
  PriceConditionKind get kind;

  /// Reconstrói a condição a partir das colunas do banco.
  static PriceCondition from(PriceConditionKind kind, {int? minimumQuantity}) => switch (kind) {
    PriceConditionKind.anyCustomer => const AnyCustomer(),
    PriceConditionKind.loyaltyMembers => const LoyaltyMembers(),
    PriceConditionKind.wholesale => Wholesale(minimumQuantity: minimumQuantity),
  };
}

/// Qualquer cliente leva uma unidade por esse preço (o varejo).
final class AnyCustomer extends PriceCondition {
  const AnyCustomer();

  @override
  PriceConditionKind get kind => PriceConditionKind.anyCustomer;

  @override
  bool operator ==(Object other) => other is AnyCustomer;

  @override
  int get hashCode => kind.hashCode;

  @override
  String toString() => 'AnyCustomer';
}

/// Vale com o cartão, o clube ou o app da loja.
final class LoyaltyMembers extends PriceCondition {
  const LoyaltyMembers();

  @override
  PriceConditionKind get kind => PriceConditionKind.loyaltyMembers;

  @override
  bool operator ==(Object other) => other is LoyaltyMembers;

  @override
  int get hashCode => kind.hashCode;

  @override
  String toString() => 'LoyaltyMembers';
}

/// Vale a partir de [minimumQuantity] unidades, quando a etiqueta informa.
final class Wholesale extends PriceCondition {
  const Wholesale({this.minimumQuantity}) : assert(minimumQuantity == null || minimumQuantity > 0);

  final int? minimumQuantity;

  @override
  PriceConditionKind get kind => PriceConditionKind.wholesale;

  @override
  bool operator ==(Object other) => other is Wholesale && other.minimumQuantity == minimumQuantity;

  @override
  int get hashCode => Object.hash(kind, minimumQuantity);

  @override
  String toString() => 'Wholesale(${minimumQuantity ?? '?'})';
}

/// Tipos de [PriceCondition], na forma gravada no banco (`textEnum`).
enum PriceConditionKind { anyCustomer, loyaltyMembers, wholesale }
