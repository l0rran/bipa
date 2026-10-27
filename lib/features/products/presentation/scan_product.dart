import 'package:bipa/core/navigation/routes.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/products/presentation/product_form_page.dart';
import 'package:bipa/features/products/presentation/products_providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Lê um código de barras e devolve o produto correspondente.
///
/// Se o código ainda não estiver cadastrado, abre o cadastro já preenchido
/// com ele. Retorna `null` se o usuário cancelar.
Future<Product?> scanAndResolveProduct(BuildContext context, WidgetRef ref) async {
  final code = await context.push<String>(Routes.scanner);
  if (code == null || !context.mounted) return null;

  final existing = await ref.read(productRepositoryProvider).findByBarcode(code);
  if (existing != null || !context.mounted) return existing;

  return context.push<Product>(
    Routes.newProduct,
    extra: ProductFormArgs(barcode: code),
  );
}
