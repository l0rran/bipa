import 'package:bipa/core/navigation/routes.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/products/presentation/new_package_sheet.dart';
import 'package:bipa/features/products/presentation/products_providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Lê um código de barras e devolve o produto da embalagem correspondente.
///
/// Se o código ainda não estiver cadastrado, abre a folha "Embalagem nova"
/// para escolher o produto (ADR 0013). Retorna `null` se o usuário cancelar.
Future<Product?> scanAndResolveProduct(BuildContext context, WidgetRef ref) async {
  final code = await context.push<String>(Routes.scanner);
  if (code == null || !context.mounted) return null;

  final existing = await ref.read(productRepositoryProvider).findByBarcode(code);
  if (existing != null || !context.mounted) return existing;

  final created = await showNewPackageSheet(context, ref, barcode: code);
  return created?.product;
}
