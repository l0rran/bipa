import 'package:bipa/core/location/geo_point.dart';
import 'package:meta/meta.dart';

/// Estabelecimento onde o usuário compra ou observa preços.
@immutable
final class Market {
  const Market({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.address,
    this.location,
  });

  final String id;
  final String name;
  final String? address;

  /// Posição do mercado; permite detectar automaticamente onde o usuário está.
  final GeoPoint? location;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  bool operator ==(Object other) =>
      other is Market &&
      other.id == id &&
      other.name == name &&
      other.address == address &&
      other.location == location &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(id, name, address, location, createdAt, updatedAt);

  @override
  String toString() => 'Market($id, $name)';
}
