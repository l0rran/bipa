import 'dart:io';

import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/design_system/components/product_category_icon.dart';
import 'package:bipa/core/design_system/components/shopping_list.dart';
import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/core/l10n/meta_join.dart';
import 'package:bipa/features/products/presentation/product_photos.dart';
import 'package:bipa/features/shopping_list/domain/shopping_list_item.dart';
import 'package:bipa/features/shopping_list/domain/shopping_list_sections.dart';
import 'package:flutter/material.dart';

/// A prévia da lista (no Início e no topo da Lista): quantos itens faltam, o
/// total estimado, as miniaturas e "Ir às compras".
class ListPreview extends StatelessWidget {
  const ListPreview({
    required this.entries,
    required this.summary,
    required this.photos,
    required this.onGoShopping,
    super.key,
  });

  final List<ShoppingListEntry> entries;
  final ShoppingListSummary summary;
  final Directory? photos;
  final VoidCallback onGoShopping;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final missing = entries.where((e) => !e.item.isChecked).toList();
    final estimate = summary.estimate?.format();
    // A estimativa diz o que deixou de fora (CE4), curto para caber na linha.
    final leftOut = estimate != null && summary.unpriced > 0;
    final unpriced = leftOut ? l10n.listUnpriced(summary.unpriced) : null;

    return ListPreviewCard(
      count: summary.remaining,
      countLabel: l10n.listItems(summary.remaining),
      estimate: estimate == null ? null : l10n.joinMeta([l10n.listEstimate(estimate), ?unpriced]),
      thumbs: [for (final entry in missing.take(3)) _ListThumb(entry: entry, photos: photos)],
      extraCount: missing.length > 3 ? missing.length - 3 : 0,
      actionLabel: l10n.listGoShopping,
      actionIcon: Icons.shopping_cart_outlined,
      onTap: onGoShopping,
      semanticLabel: [
        l10n.listPreviewSemantics(summary.remaining),
        if (estimate != null) l10n.listAbout(estimate),
        if (leftOut) l10n.marketsMissingPrices(summary.unpriced),
        l10n.listGoShopping,
      ].join(', '),
    );
  }
}

class _ListThumb extends StatelessWidget {
  const _ListThumb({required this.entry, required this.photos});

  final ShoppingListEntry entry;
  final Directory? photos;

  @override
  Widget build(BuildContext context) {
    final icon = Center(child: Icon(productCategoryIcon(entry.name), size: 20, color: context.colors.ink));
    final product = entry.product;
    final file = product == null ? null : productPhotoFile(product, photos);
    if (file == null) return icon;
    return Image.file(file, fit: BoxFit.cover, gaplessPlayback: true, errorBuilder: (_, _, _) => icon);
  }
}
