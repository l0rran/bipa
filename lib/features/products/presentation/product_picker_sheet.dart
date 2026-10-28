import 'package:bipa/core/catalog/text_fold.dart';
import 'package:bipa/core/design_system/bipa_metrics.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/design_system/bipa_typography.dart';
import 'package:bipa/core/design_system/components/product_category_icon.dart';
import 'package:bipa/core/design_system/components/product_thumb.dart';
import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/features/products/domain/product.dart';
import 'package:bipa/features/products/presentation/products_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// O que a pessoa escolheu: um produto que já existe ou o nome de um novo.
sealed class ProductChoice {
  const ProductChoice();
}

@immutable
final class ExistingProduct extends ProductChoice {
  const ExistingProduct(this.product);

  final Product product;
}

@immutable
final class NewProduct extends ProductChoice {
  const NewProduct(this.name);

  final String name;
}

/// Escolhe o produto de uma embalagem, ou cria um, a partir de uma busca que
/// começa com [initialQuery]. Sem [allowCreate], só os que existem, tirando
/// [excludeId] (para juntar um produto com outro).
Future<ProductChoice?> pickProduct(
  BuildContext context, {
  String initialQuery = '',
  bool allowCreate = true,
  String? excludeId,
  String? title,
}) {
  return showModalBottomSheet<ProductChoice>(
    context: context,
    isScrollControlled: true,
    builder: (_) => ProductPickerSheet(
      initialQuery: initialQuery,
      allowCreate: allowCreate,
      excludeId: excludeId,
      title: title,
    ),
  );
}

class ProductPickerSheet extends ConsumerStatefulWidget {
  const ProductPickerSheet({
    this.initialQuery = '',
    this.allowCreate = true,
    this.excludeId,
    this.title,
    super.key,
  });

  final String initialQuery;
  final bool allowCreate;
  final String? excludeId;

  /// Sem título, pergunta "De que produto é?".
  final String? title;

  @override
  ConsumerState<ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends ConsumerState<ProductPickerSheet> {
  late final _search = TextEditingController(text: widget.initialQuery);
  late var _query = widget.initialQuery.trim();
  late var _products = _watch();

  Stream<List<Product>> _watch() => ref.read(productRepositoryProvider).watchAll(query: _query);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(BipaSpacing.s4, 0, BipaSpacing.s4, BipaSpacing.s3),
              child: Text(widget.title ?? l10n.productPickTitle, style: BipaText.title.copyWith(color: colors.ink)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: BipaSpacing.s4),
              child: TextField(
                controller: _search,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: widget.allowCreate ? l10n.productPickSearch : l10n.productPickSearchOnly,
                  prefixIcon: const Icon(Icons.search_rounded),
                  fillColor: colors.surfaceSunken,
                ),
                onChanged: (value) => setState(() {
                  _query = value.trim();
                  _products = _watch();
                }),
              ),
            ),
            const SizedBox(height: BipaSpacing.s2),
            Flexible(
              child: StreamBuilder<List<Product>>(
                stream: _products,
                builder: (context, snapshot) {
                  final items = [
                    for (final product in snapshot.data ?? const <Product>[])
                      if (product.id != widget.excludeId) product,
                  ];
                  final exact = items.any((p) => foldText(p.name) == foldText(_query));
                  final canCreate = widget.allowCreate && _query.isNotEmpty && !exact;
                  if (snapshot.hasData && items.isEmpty && !canCreate) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: BipaSpacing.s6),
                      child: Text(
                        l10n.productPickNone,
                        textAlign: TextAlign.center,
                        style: BipaText.body.copyWith(color: colors.inkMuted),
                      ),
                    );
                  }
                  return ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(bottom: BipaSpacing.s4),
                    children: [
                      if (canCreate)
                        ListTile(
                          leading: CircleAvatar(
                            backgroundColor: colors.brandSoft,
                            foregroundColor: colors.brandText,
                            child: const Icon(Icons.add_rounded),
                          ),
                          title: Text(l10n.productPickCreate(_query)),
                          onTap: () => Navigator.of(context).pop(NewProduct(_query)),
                        ),
                      for (final product in items)
                        ListTile(
                          leading: ProductThumb(fallbackIcon: productCategoryIcon(product.name), size: 40),
                          title: Text(product.name),
                          onTap: () => Navigator.of(context).pop(ExistingProduct(product)),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
