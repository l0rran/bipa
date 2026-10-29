import 'package:bipa/core/money/money.dart';
import 'package:bipa/features/shopping_list/domain/trip_price.dart';

/// O peso, em gramas, que [total] paga a [perKilo] (ADR 0018): o que a
/// pessoa confere de cabeça ao digitar o valor da pesagem ("R$ 12,40 a R$
/// 8,99/kg dá 1,38 kg").
///
/// A conta é em inteiros (ADR 0006): centavos e gramas, arredondada ao grama
/// mais próximo (meio grama sobe). Devolve `null` quando não há conta a
/// fazer: o preço por quilo ou o valor não é positivo, ou o valor paga menos
/// que um grama.
int? weightInGrams(Money total, Money perKilo) {
  if (!total.isPositive || !perKilo.isPositive) return null;
  // total / perKilo quilos = total * 1000 / perKilo gramas; o dobro no
  // numerador e no denominador faz a divisão inteira arredondar, não cortar.
  final grams = (total.cents * 2000 + perKilo.cents) ~/ (perKilo.cents * 2);
  return grams > 0 ? grams : null;
}

/// O peso como a bandeja o diz: "1,38 kg" (duas casas, no formato brasileiro)
/// a partir de um quilo, e "450 g" abaixo dele.
String formatWeight(int grams) {
  if (grams < 1000) return '$grams g';
  // Arredondado ao centésimo de quilo (10 g), de novo em inteiros.
  final hundredths = (grams + 5) ~/ 10;
  return '${hundredths ~/ 100},${(hundredths % 100).toString().padLeft(2, '0')} kg';
}

/// O preço por quilo lido nesta compra para o produto, ou `null`: o preço da
/// gôndola do granel (ADR 0018), que não é o valor da linha.
Money? perKiloPriceOf(Iterable<TripPrice> prices, String productId) {
  for (final price in prices) {
    if (price.perKilo && price.packageId == null && price.productId == productId) return price.price;
  }
  return null;
}

/// O preço de gôndola guardado nesta compra para a linha sem embalagem do
/// produto (o [TripPrice] que não é por quilo), ou `null`. É o que
/// [isWeighingLine] pede para separar a pesagem da etiqueta sem código cujo
/// produto foi escolhido pelo nome.
TripPrice? shelfPriceOf(Iterable<TripPrice> prices, String productId) {
  for (final price in prices) {
    if (!price.perKilo && price.packageId == null && price.productId == productId) return price;
  }
  return null;
}
