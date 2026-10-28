import 'package:bipa/core/navigation/routes.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/products/domain/product_package.dart';
import 'package:bipa/features/products/presentation/new_package_sheet.dart';
import 'package:bipa/features/products/presentation/products_providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// A embalagem de um código lido e o produto dela.
typedef ScannedPackage = ({Product product, ProductPackage package});

/// Lê um código de barras e devolve a embalagem correspondente com o seu
/// produto.
///
/// Se o código ainda não estiver cadastrado, abre a folha "Embalagem nova"
/// para escolher o produto (ADR 0013). Retorna `null` se o usuário cancelar.
Future<ScannedPackage?> scanAndResolvePackage(BuildContext context, WidgetRef ref) async {
  final code = await context.push<String>(Routes.scanner);
  if (code == null || !context.mounted) return null;

  final repository = ref.read(productRepositoryProvider);
  final package = await repository.findPackageByBarcode(code);
  final product = package == null ? null : await repository.findById(package.productId);
  if (package != null && product != null) return (product: product, package: package);
  if (!context.mounted) return null;

  return showNewPackageSheet(context, ref, barcode: code);
}
