import 'package:bipa/core/money/money.dart';
import 'package:bipa/features/prices/domain/price_condition.dart';
import 'package:bipa/features/prices/domain/price_source.dart';
import 'package:bipa/features/prices/domain/price_tag.dart';
import 'package:bipa/features/prices/domain/register_price_observation.dart';
import 'package:bipa/features/products/domain/measure_unit.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/products/domain/product_package.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fakes.dart';

void main() {
  final now = DateTime(2026, 10, 27, 10, 30);

  late InMemoryProductRepository products;
  late InMemoryPriceRepository prices;
  late RegisterPriceObservation register;

  setUp(() {
    products = InMemoryProductRepository();
    prices = InMemoryPriceRepository();
    register = RegisterPriceObservation(
      products: products,
      prices: prices,
      ids: SequentialIdGenerator(),
      clock: () => now,
    );
  });

  Product existingProduct({String? barcode}) {
    final product = Product(id: 'leite', name: 'Leite', unit: MeasureUnit.liter, createdAt: now, updatedAt: now);
    products.products[product.id] = product;
    if (barcode != null) {
      products.packages['leite-1l'] = ProductPackage(
        id: 'leite-1l',
        productId: 'leite',
        barcode: barcode,
        size: 1,
        unit: MeasureUnit.liter,
        createdAt: now,
        updatedAt: now,
      );
    }
    return product;
  }

  test('registra preço de um produto pelo id', () async {
    existingProduct();

    final observation = await register(
      const RegisterPriceInput(
        marketId: 'mercado',
        productId: 'leite',
        price: Money.cents(549),
        source: PriceSource.manual,
      ),
    );

    expect(observation.productId, 'leite');
    expect(observation.observedAt, now);
    expect(prices.observations, [observation]);
  });

  test('o preço visto antes guarda a hora em que foi visto, e o registro, a de agora', () async {
    existingProduct();
    final seen = now.subtract(const Duration(minutes: 40));

    final observation = await register(
      RegisterPriceInput(
        marketId: 'mercado',
        productId: 'leite',
        price: const Money.cents(549),
        source: PriceSource.priceTag,
        otherOffers: const [PriceOffer(price: Money.cents(499), condition: LoyaltyMembers())],
        observedAt: seen,
      ),
    );

    expect((observation.observedAt, observation.createdAt), (seen, now));
    expect(prices.observations.map((o) => o.observedAt), everyElement(seen));
  });

  test('um preço digitado corrige a leitura errada sem apagá-la', () async {
    existingProduct();
    final wrong = await register(
      const RegisterPriceInput(
        marketId: 'mercado',
        productId: 'leite',
        price: Money.cents(2190),
        source: PriceSource.priceTag,
      ),
    );

    final fixed = await register(
      RegisterPriceInput(
        marketId: 'mercado',
        productId: 'leite',
        price: const Money.cents(2790),
        source: PriceSource.manual,
        supersedes: wrong.id,
      ),
    );

    expect(fixed.supersedes, wrong.id);
    expect(prices.observations, [wrong, fixed]);
    expect((await prices.watchHistory('leite').first).map((e) => e.observation), [fixed]);
  });

  test('encontra o produto pelo código de barras', () async {
    existingProduct(barcode: '7891910000197');

    final observation = await register(
      const RegisterPriceInput(
        marketId: 'mercado',
        barcode: '7891910000197',
        newProductName: 'Ignorado, pois o produto já existe',
        price: Money.cents(549),
        source: PriceSource.priceTag,
      ),
    );

    expect(observation.productId, 'leite');
    expect(observation.packageId, 'leite-1l');
    expect(products.products, hasLength(1));
  });

  test('o preço de um produto pelo id leva a embalagem do código, se for dele', () async {
    existingProduct(barcode: '7891910000197');

    final observation = await register(
      const RegisterPriceInput(
        marketId: 'mercado',
        productId: 'leite',
        barcode: '7891910000197',
        price: Money.cents(549),
        source: PriceSource.priceTag,
      ),
    );

    expect(observation.packageId, 'leite-1l');
  });

  test('um código novo informado com o produto vira embalagem dele', () async {
    existingProduct();

    final observation = await register(
      const RegisterPriceInput(
        marketId: 'mercado',
        productId: 'leite',
        barcode: '7891000100103',
        price: Money.cents(549),
        source: PriceSource.priceTag,
      ),
    );

    final package = products.packages[observation.packageId]!;
    expect((package.productId, package.barcode), ('leite', '7891000100103'));
    // Na unidade do produto, não na padrão de um produto novo.
    expect(package.unit, MeasureUnit.liter);
  });

  test('cadastra o produto quando o código ainda não existe', () async {
    final observation = await register(
      const RegisterPriceInput(
        marketId: 'mercado',
        barcode: '7891000100103',
        newProductName: '  Leite condensado ',
        price: Money.cents(799),
        source: PriceSource.priceTag,
      ),
    );

    final created = products.products[observation.productId]!;
    expect(created.name, 'Leite condensado');
    final package = products.packages[observation.packageId]!;
    expect((package.productId, package.barcode), (created.id, '7891000100103'));
  });

  test('guarda o preço normal apenas se for maior que o pago', () async {
    existingProduct();

    final promotion = await register(
      const RegisterPriceInput(
        marketId: 'mercado',
        productId: 'leite',
        price: Money.cents(2490),
        regularPrice: Money.cents(3290),
        source: PriceSource.priceTag,
      ),
    );
    final inconsistent = await register(
      const RegisterPriceInput(
        marketId: 'mercado',
        productId: 'leite',
        price: Money.cents(2490),
        regularPrice: Money.cents(1990),
        source: PriceSource.priceTag,
      ),
    );

    expect(promotion.isPromotion, isTrue);
    expect(inconsistent.regularPrice, isNull);
  });

  test('grava cada preço da etiqueta com a sua condição, no mesmo produto e horário', () async {
    final main = await register(
      const RegisterPriceInput(
        marketId: 'assai',
        barcode: '7891000100103',
        newProductName: 'Feijão Carioca 1kg',
        price: Money.cents(805),
        source: PriceSource.priceTag,
        otherOffers: [
          PriceOffer(price: Money.cents(785), condition: LoyaltyMembers()),
          PriceOffer(price: Money.cents(785), condition: Wholesale(minimumQuantity: 10)),
        ],
      ),
    );

    expect(main.condition, const AnyCustomer());
    expect(products.products, hasLength(1));
    expect(prices.observations.map((o) => (o.condition, o.price.cents)), [
      (const AnyCustomer(), 805),
      (const LoyaltyMembers(), 785),
      (const Wholesale(minimumQuantity: 10), 785),
    ]);
    expect(prices.observations.map((o) => o.productId).toSet(), {main.productId});
    expect(prices.observations.map((o) => o.observedAt).toSet(), {now});
  });

  test('ignora ofertas repetidas na condição do preço principal', () async {
    existingProduct();

    await register(
      const RegisterPriceInput(
        marketId: 'assai',
        productId: 'leite',
        price: Money.cents(179),
        condition: LoyaltyMembers(),
        source: PriceSource.priceTag,
        otherOffers: [
          PriceOffer(price: Money.cents(199), condition: LoyaltyMembers()),
          PriceOffer(price: Money.cents(179), condition: Wholesale(minimumQuantity: 6)),
        ],
      ),
    );

    expect(prices.observations.map((o) => o.condition), const [LoyaltyMembers(), Wholesale(minimumQuantity: 6)]);
  });

  test('rejeita preço zero', () {
    expect(
      () => register(
        const RegisterPriceInput(
          marketId: 'mercado',
          productId: 'leite',
          price: Money.zero,
          source: PriceSource.manual,
        ),
      ),
      throwsA(isA<InvalidPriceException>()),
    );
  });

  test('exige nome para produto novo', () {
    expect(
      () => register(
        const RegisterPriceInput(
          marketId: 'mercado',
          barcode: '7891000100103',
          price: Money.cents(100),
          source: PriceSource.manual,
        ),
      ),
      throwsA(isA<MissingProductNameException>()),
    );
  });

  test('falha quando o produto informado não existe', () {
    expect(
      () => register(
        const RegisterPriceInput(
          marketId: 'mercado',
          productId: 'inexistente',
          price: Money.cents(100),
          source: PriceSource.manual,
        ),
      ),
      throwsA(isA<ProductNotFoundException>()),
    );
  });
}
