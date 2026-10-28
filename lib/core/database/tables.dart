import 'package:bipa/core/catalog/product_kind.dart';
import 'package:bipa/features/prices/domain/price_condition.dart';
import 'package:bipa/features/prices/domain/price_source.dart';
import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:bipa/features/stock/domain/stock_location.dart';
import 'package:bipa/features/stock/domain/stock_movement_reason.dart';
import 'package:drift/drift.dart';

// Convenções do esquema:
// * IDs são UUIDs gerados no aparelho, para sincronizar sem colisões.
// * `syncedAt` marca o que já foi enviado à base comunitária (nulo = pendente).
//   Só dados compartilháveis têm essa coluna: estoque é sempre privado.

/// O que se usa em casa (ADR 0013). Até o esquema v6, código, marca e
/// tamanho ficavam aqui; no v7 passaram para [ProductPackages].
@DataClassName('ProductRow')
class Products extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 160)();
  TextColumn get unit => textEnum<MeasureUnit>()();

  /// Caminho relativo da foto na pasta de fotos do app (esquema v2).
  TextColumn get photoPath => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// As embalagens de cada produto: código, marca e tamanho (ADR 0013,
/// esquema v7).
@DataClassName('ProductPackageRow')
@TableIndex(name: 'product_packages_product', columns: {#productId})
class ProductPackages extends Table {
  TextColumn get id => text()();
  TextColumn get productId => text().references(Products, #id, onDelete: KeyAction.cascade)();
  TextColumn get barcode => text().nullable()();
  TextColumn get brand => text().nullable()();
  RealColumn get size => real().nullable()();
  TextColumn get unit => textEnum<MeasureUnit>()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  // SQLite permite vários NULLs em uma coluna UNIQUE: embalagens sem código
  // de barras não conflitam entre si.
  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {barcode},
  ];
}

@DataClassName('MarketRow')
class Markets extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 120)();
  TextColumn get address => text().nullable()();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Observações de preço: apenas inseridas, nunca atualizadas.
@DataClassName('PriceObservationRow')
@TableIndex(name: 'price_observations_product_date', columns: {#productId, #observedAt})
@TableIndex(name: 'price_observations_package', columns: {#packageId})
class PriceObservations extends Table {
  TextColumn get id => text()();
  TextColumn get productId =>
      text().references(Products, #id, onDelete: KeyAction.cascade)();
  TextColumn get marketId =>
      text().references(Markets, #id, onDelete: KeyAction.cascade)();

  /// A embalagem que tinha esse preço (esquema v7). Nula em preços de produto
  /// sem embalagem, como os a granel.
  TextColumn get packageId =>
      text().nullable().references(ProductPackages, #id, onDelete: KeyAction.setNull)();
  IntColumn get priceCents => integer()();
  IntColumn get regularPriceCents => integer().nullable()();

  /// Condição do preço (ADR 0011, esquema v3). Observações antigas são de varejo.
  TextColumn get conditionKind => textEnum<PriceConditionKind>().withDefault(const Constant('anyCustomer'))();

  /// Mínimo de unidades do preço de atacado, quando a etiqueta informa.
  IntColumn get minimumQuantity => integer().nullable()();
  TextColumn get source => textEnum<PriceSource>()();
  DateTimeColumn get observedAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// O que há em casa, por entrada (ADR 0013, esquema v7): cada compra é um
/// lote, com a embalagem e quando entrou. 1 de 5 kg e 1 de 10 kg somam
/// 15 kg, e o "Usei um" tira do lote mais antigo. A soma dos lotes é sempre
/// a quantidade do produto em [StockItems].
@DataClassName('StockLotRow')
@TableIndex(name: 'stock_lots_product', columns: {#productId})
class StockLots extends Table {
  TextColumn get id => text()();
  TextColumn get productId => text().references(Products, #id, onDelete: KeyAction.cascade)();

  /// Nula quando o produto não tem embalagem (ou ela foi apagada).
  TextColumn get packageId => text().nullable().references(ProductPackages, #id, onDelete: KeyAction.setNull)();
  RealColumn get quantity => real()();
  DateTimeColumn get since => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Estado atual do estoque: um registro por produto.
@DataClassName('StockItemRow')
class StockItems extends Table {
  TextColumn get productId =>
      text().references(Products, #id, onDelete: KeyAction.cascade)();
  RealColumn get quantity => real()();
  RealColumn get minimumQuantity => real().nullable()();
  TextColumn get location => textEnum<StockLocation>()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {productId};
}

/// Histórico de entradas e saídas, base para prever o consumo.
@DataClassName('StockMovementRow')
class StockMovements extends Table {
  TextColumn get id => text()();
  TextColumn get productId =>
      text().references(Products, #id, onDelete: KeyAction.cascade)();
  RealColumn get delta => real()();
  TextColumn get reason => textEnum<StockMovementReason>()();
  DateTimeColumn get occurredAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Lista de compras: privada, nunca sincronizada (ADR 0007), por isso sem
/// `syncedAt`. Itens escritos à mão não têm produto.
@DataClassName('ShoppingListItemRow')
class ShoppingListItems extends Table {
  TextColumn get id => text()();
  TextColumn get productId => text().nullable().references(Products, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text().withLength(min: 1, max: 160)();
  DateTimeColumn get addedAt => dateTime()();
  DateTimeColumn get checkedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Idas ao mercado (o modo compra). Privadas, como a lista.
@DataClassName('ShoppingTripRow')
class ShoppingTrips extends Table {
  TextColumn get id => text()();
  TextColumn get marketId => text().nullable().references(Markets, #id, onDelete: KeyAction.setNull)();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get finishedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Carrinho de cada compra: um registro por embalagem, com a quantidade
/// bipada. O repositório garante um item por embalagem (ou por produto, sem
/// embalagem): como a embalagem pode ser nula, uma chave única no SQLite não
/// garantiria isso.
@DataClassName('CartItemRow')
class CartItems extends Table {
  TextColumn get id => text()();
  TextColumn get tripId => text().references(ShoppingTrips, #id, onDelete: KeyAction.cascade)();
  TextColumn get productId => text().references(Products, #id, onDelete: KeyAction.cascade)();

  /// A embalagem bipada (esquema v7).
  TextColumn get packageId => text().nullable().references(ProductPackages, #id, onDelete: KeyAction.setNull)();
  IntColumn get quantity => integer().withDefault(const Constant(1))();
  IntColumn get priceCents => integer().nullable()();

  /// O preço veio do histórico do mercado, não foi lido nem digitado nesta
  /// compra (esquema v9).
  BoolColumn get priceEstimated => boolean().withDefault(const Constant(false))();
  BoolColumn get take => boolean().withDefault(const Constant(true))();
  DateTimeColumn get addedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// A ordem das seções em cada mercado, aprendida com as compras (ADR 0014,
/// esquema v8). Privada, como a lista. A seção é gravada pelo nome do
/// [Aisle]: renomear um valor do enum exige migração.
@DataClassName('MarketAisleRow')
class MarketAisles extends Table {
  TextColumn get marketId => text().references(Markets, #id, onDelete: KeyAction.cascade)();
  TextColumn get aisle => textEnum<Aisle>()();

  /// De 0 (entrada) a 1 (fundo).
  RealColumn get position => real()();

  /// Em quantas compras a seção foi vista nesse mercado.
  IntColumn get samples => integer()();

  @override
  Set<Column<Object>> get primaryKey => {marketId, aisle};
}
