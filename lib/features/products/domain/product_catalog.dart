import 'package:bipa/core/catalog/product_kind.dart';
import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:bipa/features/products/domain/package_origin.dart';
import 'package:meta/meta.dart';

/// Uma embalagem do catálogo pronto (ADR 0024): o que o Open Food Facts e as
/// bases irmãs sabem de um código de barras. Não é da pessoa: ao ser
/// bipada, vira uma cópia na base dela, que ela confere antes.
@immutable
final class CatalogPackage {
  const CatalogPackage({
    required this.barcode,
    required this.name,
    required this.source,
    this.brand,
    this.quantity,
    this.size,
    this.unit,
    this.kind,
  });

  final String barcode;

  /// O nome do produto como está no catálogo ("Arroz Branco Tipo 1 Tio
  /// João"), às vezes em caixa alta ou incompleto.
  final String name;
  final String? brand;

  /// A quantidade como texto livre ("5 kg", "6 x 200 ml"), quando o catálogo
  /// não conseguiu ler tamanho e unidade.
  final String? quantity;
  final double? size;
  final MeasureUnit? unit;

  /// A categoria convertida para o tipo do app; `null` sem categoria.
  final ProductKind? kind;

  /// A base de onde veio, que a tela do produto cita.
  final PackageOrigin source;

  @override
  bool operator ==(Object other) =>
      other is CatalogPackage &&
      other.barcode == barcode &&
      other.name == name &&
      other.brand == brand &&
      other.quantity == quantity &&
      other.size == size &&
      other.unit == unit &&
      other.kind == kind &&
      other.source == source;

  @override
  int get hashCode => Object.hash(barcode, name, brand, quantity, size, unit, kind, source);

  @override
  String toString() => 'CatalogPackage($barcode, $name, $brand, $size ${unit?.symbol}, ${source.name})';
}

/// O catálogo pronto de produtos, só de leitura e separado dos dados da
/// pessoa (ADR 0023, seção 6). Sem o arquivo do catálogo, ele é vazio: nada
/// é achado, e o bipe segue como antes.
abstract interface class ProductCatalog {
  /// A embalagem do código [barcode], ou `null` se o catálogo não a tem.
  Future<CatalogPackage?> find(String barcode);

  /// O aviso de atribuição que o catálogo traz ("Contém informações do Open
  /// Food Facts…"), para a tela "Sobre"; `null` sem catálogo.
  Future<String?> attribution();
}

/// O catálogo sem nenhum produto: o app sem o arquivo, ou nos testes.
final class EmptyProductCatalog implements ProductCatalog {
  const EmptyProductCatalog();

  @override
  Future<CatalogPackage?> find(String barcode) async => null;

  @override
  Future<String?> attribution() async => null;
}
