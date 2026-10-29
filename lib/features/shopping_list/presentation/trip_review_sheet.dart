import 'package:bipa/core/design_system/bipa_metrics.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/design_system/bipa_typography.dart';
import 'package:bipa/core/design_system/components/bipa_toast.dart';
import 'package:bipa/core/design_system/components/price_tag.dart';
import 'package:bipa/core/design_system/components/save_badge.dart';
import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/core/l10n/meta_join.dart';
import 'package:bipa/features/shopping_list/domain/trip_review.dart';
import 'package:flutter/material.dart';

/// Como a compra acaba, escolhido na folha "Fim da compra".
enum TripEnd { finish, cancel }

/// Abre a folha "Fim da compra". Devolve `null` em "Continuar comprando" ou
/// ao fechar a folha.
Future<TripEnd?> showTripReview(BuildContext context, TripReview review) => showModalBottomSheet<TripEnd>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => BipaSheetToasts(child: TripReviewSheet(review: review)),
);

/// A folha "Fim da compra" (protótipo "Fim da compra"): o total em
/// destaque, quantas embalagens vão para casa, a economia contra outro
/// mercado e o que faltou da lista, antes de confirmar.
class TripReviewSheet extends StatelessWidget {
  const TripReviewSheet({required this.review, super.key});

  final TripReview review;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final spent = review.spent;
    final savings = review.savings;
    final missing = review.missing;
    // A linha da etiqueta: o que vai para casa e, se for o caso, que o total
    // tem preço estimado ou deixou itens sem preço de fora.
    final packagesLine = l10n.joinMeta([
      l10n.tripReviewPackages(review.packages),
      if (review.estimated) l10n.tripReviewEstimated,
      if (review.unpriced > 0) l10n.marketsMissingPrices(review.unpriced),
    ]);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        BipaSpacing.s4,
        0,
        BipaSpacing.s4,
        BipaSpacing.s4 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(l10n.tripReviewTitle, style: BipaText.headline.copyWith(fontSize: 24, color: colors.ink)),
          ),
          const SizedBox(height: BipaSpacing.s4),
          if (spent != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: PriceTagHero(price: spent, unitLine: packagesLine),
            )
          else
            Text(packagesLine, style: BipaText.bodyLarge.copyWith(color: colors.ink)),
          if (savings != null) ...[
            const SizedBox(height: BipaSpacing.s4),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: SaveBadge(label: l10n.tripReviewSavings(savings.amount.format(), savings.marketName)),
            ),
          ],
          if (missing.isNotEmpty) ...[
            const SizedBox(height: BipaSpacing.s4),
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surfaceSunken,
                borderRadius: BorderRadius.circular(BipaRadius.md),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: BipaSpacing.s4, vertical: BipaSpacing.s3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.tripReviewMissing(missing.length), style: BipaText.bodyLarge.copyWith(color: colors.ink)),
                    Text(
                      l10n.tripReviewMissingDetail(
                        missing.length,
                        l10n.joinNames([
                          for (final (:name, :quantity) in missing)
                            quantity > 1 ? l10n.cartQuantity(quantity, name) : name,
                        ]),
                      ),
                      style: BipaText.body.copyWith(fontSize: 13, color: colors.inkMuted),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: BipaSpacing.s6),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colors.ink,
              foregroundColor: colors.surface,
              minimumSize: const Size.fromHeight(56),
            ),
            onPressed: () => Navigator.of(context).pop(TripEnd.finish),
            child: Text(l10n.tripReviewConfirm),
          ),
          const SizedBox(height: BipaSpacing.s2),
          OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.tripKeep),
          ),
          // Desistir é a saída de menos peso: só texto, e confirma depois.
          const SizedBox(height: BipaSpacing.s1),
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48), foregroundColor: colors.inkMuted),
            onPressed: () => Navigator.of(context).pop(TripEnd.cancel),
            child: Text(l10n.tripCancel),
          ),
        ],
      ),
    );
  }
}
