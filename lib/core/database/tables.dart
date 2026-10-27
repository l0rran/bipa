import 'package:bipa/features/prices/domain/price_source.dart';
import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:bipa/features/stock/domain/stock_location.dart';
import 'package:bipa/features/stock/domain/stock_movement_reason.dart';
import 'package:drift/drift.dart';

// Convenções do esquema:
// * IDs são UUIDs gerados no aparelho, para sincronizar sem colisões.
// * `syncedAt` marca o que já foi enviado à base comunitária (nulo = pendente).
//   Só dados compartilháveis têm essa coluna: estoque é sempre privado.

@DataClassName('ProductRow')
class Products extends Table {
  TextColumn get id => text()();
  TextColumn get barcode => text().nullable()();
  TextColumn get name => text().withLength(min: 1, max: 160)();
  TextColumn get brand => text().nullable()();
  TextColumn get unit => textEnum<MeasureUnit>()();
  RealColumn get packageSize => real().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  // SQLite permite vários NULLs em uma coluna UNIQUE: produtos sem código
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
class PriceObservations extends Table {
  TextColumn get id => text()();
  TextColumn get productId =>
      text().references(Products, #id, onDelete: KeyAction.cascade)();
  TextColumn get marketId =>
      text().references(Markets, #id, onDelete: KeyAction.cascade)();
  IntColumn get priceCents => integer()();
  IntColumn get regularPriceCents => integer().nullable()();
  TextColumn get source => textEnum<PriceSource>()();
  DateTimeColumn get observedAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

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
