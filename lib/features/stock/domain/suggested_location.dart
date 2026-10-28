import 'package:bipa/core/catalog/product_kind.dart';
import 'package:bipa/features/stock/domain/stock_location.dart';

/// Local em que um item novo costuma ficar em casa, deduzido do tipo do
/// produto (a mesma classificação do ícone e da seção do mercado).
///
/// É só uma sugestão para o item que nasce agora: quem já tem local escolhido
/// o mantém. Na dúvida, Despensa.
StockLocation suggestedLocation(String productName) => switch (ProductKind.of(productName)) {
  ProductKind.dairy || ProductKind.eggs || ProductKind.meat || ProductKind.fish => StockLocation.fridge,
  ProductKind.frozen => StockLocation.freezer,
  ProductKind.laundry || ProductKind.cleaning => StockLocation.cleaning,
  ProductKind.hygiene => StockLocation.bathroom,
  _ => StockLocation.pantry,
};
