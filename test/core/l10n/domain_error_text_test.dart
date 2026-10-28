import 'package:bipa/core/errors/domain_exception.dart';
import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/core/l10n/app_localizations_pt.dart';
import 'package:bipa/core/l10n/domain_error_text.dart';
import 'package:bipa/features/prices/domain/register_price_observation.dart';
import 'package:bipa/features/products/domain/product_repository.dart';
import 'package:bipa/features/products/domain/register_package.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final AppLocalizations l10n = AppLocalizationsPt();

  test('cada erro do domínio vira o texto certo do ARB', () {
    final cases = <DomainException, String>{
      const InvalidPriceException(): l10n.priceNotPositive,
      const MissingProductNameException(): l10n.productNameMissing,
      const ProductNotFoundException('p1'): l10n.productNotFound,
      const MissingPackageProductException(): l10n.packageProductMissing,
      const InvalidPackageSizeException(): l10n.packageSizeNotPositive,
      const ScaleBarcodeException(): l10n.barcodeScale,
    };
    cases.forEach((error, text) {
      expect(domainErrorText(l10n, error), text);
      expect(text, isNotEmpty);
    });
  });

  test('código repetido traz o código e o nome do produto no texto', () {
    final error = DuplicateBarcodeException(barcode: '789', productName: 'Arroz');
    expect(domainErrorText(l10n, error), l10n.packageDuplicate('789', 'Arroz'));
    expect(domainErrorText(l10n, error), contains('Arroz'));
  });

  test('o enum tem os sete códigos mapeados', () {
    // O switch de domainErrorText é exaustivo; um código novo quebra a
    // compilação lá e lembra de cobrir aqui.
    expect(DomainErrorCode.values, hasLength(7));
  });
}
