import 'dart:convert';

import 'package:bipa/core/money/money.dart';
import 'package:bipa/features/prices/domain/price_condition.dart';
import 'package:bipa/features/prices/domain/price_tag.dart';
import 'package:drift/drift.dart';

/// Os outros preços de uma etiqueta (ADR 0011) numa coluna de texto, em
/// JSON: são poucos (cartão e atacado) e só voltam inteiros, para virar
/// observações (ADR 0020).
///
/// `[{"cents": 499, "condition": "loyaltyMembers"},
///   {"cents": 459, "condition": "wholesale", "minimumQuantity": 3}]`
///
/// As chaves e os nomes das condições fazem parte do formato do backup
/// (ADR 0023): renomear um deles exige migração (convenções em `tables.dart`).
final class PriceOffersConverter extends TypeConverter<List<PriceOffer>, String> {
  const PriceOffersConverter();

  @override
  List<PriceOffer> fromSql(String fromDb) => [
    for (final item in jsonDecode(fromDb) as List<dynamic>)
      if (item case {'cents': final int cents, 'condition': final String condition})
        PriceOffer(
          price: Money.cents(cents),
          condition: PriceCondition.from(
            PriceConditionKind.values.byName(condition),
            minimumQuantity: item['minimumQuantity'] as int?,
          ),
          regularPrice: switch (item['regularCents']) {
            final int regular => Money.cents(regular),
            _ => null,
          },
        ),
  ];

  @override
  String toSql(List<PriceOffer> value) => jsonEncode([
    for (final offer in value)
      {
        'cents': offer.price.cents,
        'condition': offer.condition.kind.name,
        if (offer.condition case Wholesale(:final minimumQuantity?)) 'minimumQuantity': minimumQuantity,
        if (offer.regularPrice case final regular?) 'regularCents': regular.cents,
      },
  ]);
}
