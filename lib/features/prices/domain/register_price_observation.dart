import 'package:bipa/core/errors/domain_exception.dart';
import 'package:bipa/core/id/id_generator.dart';
import 'package:bipa/core/money/money.dart';
import 'package:bipa/core/time/clock.dart';
import 'package:bipa/features/prices/domain/price_condition.dart';
import 'package:bipa/features/prices/domain/price_observation.dart';
import 'package:bipa/features/prices/domain/price_repository.dart';
import 'package:bipa/features/prices/domain/price_source.dart';
import 'package:bipa/features/prices/domain/price_tag.dart';
import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/products/domain/product_package.dart';
import 'package:bipa/features/products/domain/product_repository.dart';
import 'package:meta/meta.dart';

/// Dados informados pelo usuário ao registrar um preço.
///
/// O produto é resolvido nesta ordem: [productId], [barcode] de uma embalagem
/// já cadastrada ou, por fim, um produto novo chamado [newProductName]. A
/// embalagem do preço é [packageId] ou a do [barcode]; um produto novo com
/// código ganha uma embalagem com ele (ADR 0013).
///
/// [otherOffers] são os outros preços da mesma etiqueta, com outras condições
/// (ADR 0011): cada um vira uma observação, no mesmo horário.
@immutable
final class RegisterPriceInput {
  const RegisterPriceInput({
    required this.marketId,
    required this.price,
    required this.source,
    this.regularPrice,
    this.condition = const AnyCustomer(),
    this.otherOffers = const [],
    this.productId,
    this.packageId,
    this.barcode,
    this.newProductName,
    this.newProductUnit = MeasureUnit.unit,
  });

  final String marketId;
  final Money price;
  final Money? regularPrice;
  final PriceCondition condition;
  final List<PriceOffer> otherOffers;
  final PriceSource source;
  final String? productId;
  final String? packageId;
  final String? barcode;
  final String? newProductName;
  final MeasureUnit newProductUnit;
}

/// Caso de uso: registra o preço de um produto em um mercado, cadastrando o
/// produto na hora quando ele ainda não existe.
final class RegisterPriceObservation {
  RegisterPriceObservation({
    required ProductRepository products,
    required PriceRepository prices,
    required IdGenerator ids,
    required Clock clock,
  }) : _products = products,
       _prices = prices,
       _ids = ids,
       _clock = clock;

  final ProductRepository _products;
  final PriceRepository _prices;
  final IdGenerator _ids;
  final Clock _clock;

  /// Retorna a observação do preço principal ([RegisterPriceInput.price]).
  Future<PriceObservation> call(RegisterPriceInput input) async {
    if (!input.price.isPositive) throw const InvalidPriceException();

    final (product, package) = await _resolve(input);
    final now = _clock();

    PriceObservation observe(PriceOffer offer) => PriceObservation(
      id: _ids.newId(),
      productId: product.id,
      packageId: package?.id,
      marketId: input.marketId,
      price: offer.price,
      regularPrice: _promotionRegularPrice(offer),
      condition: offer.condition,
      source: input.source,
      observedAt: now,
      createdAt: now,
    );

    final main = observe(
      PriceOffer(price: input.price, condition: input.condition, regularPrice: input.regularPrice),
    );
    // Uma observação por condição: repetir a do principal duplicaria o preço.
    final recorded = {input.condition};
    final others = [
      for (final offer in input.otherOffers)
        if (offer.price.isPositive && recorded.add(offer.condition)) observe(offer),
    ];
    await _prices.addAll([main, ...others]);
    return main;
  }

  /// Um "preço sem desconto" menor ou igual ao pago não indica promoção.
  static Money? _promotionRegularPrice(PriceOffer offer) {
    final regular = offer.regularPrice;
    return regular != null && regular > offer.price ? regular : null;
  }

  Future<(Product, ProductPackage?)> _resolve(RegisterPriceInput input) async {
    final barcode = input.barcode;
    final byBarcode = barcode == null ? null : await _products.findPackageByBarcode(barcode);

    if (input.productId case final id?) {
      final product = await _products.findById(id) ?? (throw ProductNotFoundException(id));
      final package = switch (input.packageId) {
        final packageId? => await _products.findPackageById(packageId),
        null => byBarcode,
      };
      // Uma embalagem de outro produto não vale para este.
      return (product, package?.productId == product.id ? package : null);
    }

    if (byBarcode != null) {
      final product = await _products.findById(byBarcode.productId);
      if (product != null) return (product, byBarcode);
    }

    final name = input.newProductName?.trim() ?? '';
    if (name.isEmpty) throw const MissingProductNameException();

    final now = _clock();
    final product = Product(
      id: _ids.newId(),
      name: name,
      unit: input.newProductUnit,
      createdAt: now,
      updatedAt: now,
    );
    await _products.save(product);
    if (barcode == null) return (product, null);

    final package = ProductPackage(
      id: _ids.newId(),
      productId: product.id,
      barcode: barcode,
      unit: input.newProductUnit,
      createdAt: now,
      updatedAt: now,
    );
    await _products.savePackage(package);
    return (product, package);
  }
}

final class InvalidPriceException extends DomainException {
  const InvalidPriceException() : super('Informe um preço maior que zero.');
}

final class MissingProductNameException extends DomainException {
  const MissingProductNameException() : super('Informe o nome do produto.');
}

final class ProductNotFoundException extends DomainException {
  const ProductNotFoundException(this.productId) : super('Produto não encontrado.');

  final String productId;
}
