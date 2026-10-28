import 'package:bipa/core/id/id_generator.dart';
import 'package:bipa/core/time/clock.dart';
import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/products/domain/product_repository.dart';

/// Caso de uso: cadastra um produto vendido a granel, por quilo e sem
/// embalagem ("Banana prata", "Tomate italiano"). É o que a etiqueta da
/// balança e a de gôndola por kg pedem quando o produto ainda não existe
/// (ADR 0018).
final class CreateProductByWeight {
  const CreateProductByWeight({required ProductRepository products, required IdGenerator ids, required Clock clock})
    : _products = products,
      _ids = ids,
      _clock = clock;

  final ProductRepository _products;
  final IdGenerator _ids;
  final Clock _clock;

  Future<Product> call(String name) async {
    final now = _clock();
    final product = Product(
      id: _ids.newId(),
      name: name.trim(),
      unit: MeasureUnit.kilogram,
      createdAt: now,
      updatedAt: now,
    );
    await _products.save(product);
    return product;
  }
}
