import 'dart:async';
import 'dart:io';

import 'package:bipa/core/design_system/bipa_metrics.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/design_system/bipa_typography.dart';
import 'package:bipa/core/design_system/components/bipa_toast.dart';
import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/features/backup/domain/backup_info.dart';
import 'package:bipa/features/backup/domain/restore_backup.dart';
import 'package:bipa/features/backup/presentation/backup_files.dart';
import 'package:bipa/features/backup/presentation/backup_labels.dart';
import 'package:bipa/features/backup/presentation/backup_providers.dart';
import 'package:bipa/features/backup/presentation/restore_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// O cartão "Backup encontrado" do Início no celular novo (protótipo
/// InicioBackupEncontrado, ADR 0023, B1): o Android trouxe o `ultimo.bipa`
/// do celular antigo, e a casa está vazia. Fica no lugar do convite da casa
/// vazia, com a data com o ano, os números do arquivo, "Restaurar" (neutro)
/// e "Começar do zero" (secundário). Nada é restaurado sozinho. Com a casa
/// já em uso, o Início mostra o [PendingBackupCard], menor.
///
/// "Restaurar" confere e troca com o botão carregando, sem a folha de
/// confirmação, porque a casa vazia (nenhuma linha em nenhuma tabela, inclusive
/// a lista e os mercados) não perde nada; se já há o que perder, passa pela
/// folha, com o "Desfazer". "Começar do zero" tira o cartão com Desfazer por 10 s;
/// até o aviso sair, o arquivo continua pendente (Ajustes o restaura).
class RestoreOfferCard extends ConsumerStatefulWidget {
  const RestoreOfferCard({required this.offer, super.key});

  final BackupInfo offer;

  @override
  ConsumerState<RestoreOfferCard> createState() => _RestoreOfferCardState();
}

class _RestoreOfferCardState extends ConsumerState<RestoreOfferCard> {
  var _restoring = false;

  /// O arquivo não serve: o cartão mostra o problema, com "Começar do zero".
  BackupProblem? _problem;

  Future<void> _restore() async {
    final backup = ref.read(backupProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    setState(() => _restoring = true);
    final PreparedRestore prepared;
    try {
      prepared = await backup.prepareRestore(File(widget.offer.path));
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _restoring = false;
          _problem = BackupProblem.of(error);
        });
      }
      return;
    }
    if (prepared.currentIsEmpty) {
      // A casa não tem nenhuma linha em nenhuma tabela (nem lista, nem
      // mercado): não há o que perder. Pronto, o cartão some com a oferta e o
      // Início se enche. Os três números do resumo não decidem isso (BK4).
      await applyRestoreAndNotify(
        backup: backup,
        prepared: prepared,
        messenger: messenger,
        l10n: l10n,
        offerUndo: false,
        fromOtherPhone: true,
      );
      if (mounted) setState(() => _restoring = false);
      return;
    }
    if (!mounted) {
      await backup.cancelRestore(prepared);
      return;
    }
    setState(() => _restoring = false);
    await showRestoreSheet(context, preparing: Future.value(prepared), fromOtherPhone: true);
  }

  /// "Começar do zero": o cartão some na hora; o arquivo só é adotado quando
  /// o aviso sai sem o "Desfazer".
  void _startFresh() => _setAside(context, ref, (l10n, date) => l10n.backupOfferDismissed(date));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final offer = widget.offer;
    final problem = _problem;
    final stacked = MediaQuery.textScalerOf(context).scale(10) >= 15;

    final fresh = OutlinedButton(
      onPressed: _restoring ? null : _startFresh,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: BipaSpacing.s3),
      ),
      child: Text(l10n.backupOfferFresh, textAlign: TextAlign.center),
    );
    final Widget first = problem == null
        ? NeutralButton(
            label: l10n.backupOfferRestore,
            busyLabel: l10n.backupRestoring,
            busy: _restoring,
            onPressed: _restoring ? null : _restore,
          )
        : OutlinedButton(
            onPressed: () => unawaited(ref.read(backupFilesProvider).openStorePage()),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 52),
              padding: const EdgeInsets.symmetric(horizontal: BipaSpacing.s3),
            ),
            child: Text(l10n.backupUpdateApp, textAlign: TextAlign.center),
          );
    final showFirst = problem != BackupProblem.notRecognized;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(BipaRadius.lg),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ExcludeSemantics(child: Icon(Icons.cloud_outlined, size: 16, color: colors.inkMuted)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l10n.backupOfferEyebrow,
                    style: BipaText.caption.copyWith(fontWeight: FontWeight.w700, color: colors.inkMuted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: BipaSpacing.s4),
            if (problem == null) ...[
              _OfferTitle(
                offer: offer,
                style: BipaText.title.copyWith(fontWeight: FontWeight.w800, color: colors.ink),
              ),
              const SizedBox(height: BipaSpacing.s4),
              Divider(color: colors.line),
              const SizedBox(height: BipaSpacing.s4),
              BackupFacts(summary: offer.manifest.summary),
            ] else
              Semantics(
                liveRegion: true,
                container: true,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ExcludeSemantics(
                      child: Icon(
                        problem == BackupProblem.fromNewerApp
                            ? Icons.system_update_outlined
                            : Icons.broken_image_outlined,
                        size: 28,
                        color: colors.alertText,
                      ),
                    ),
                    const SizedBox(width: BipaSpacing.s3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Semantics(
                            header: true,
                            child: Text(
                              problem == BackupProblem.fromNewerApp
                                  ? l10n.backupNewerTitle
                                  : l10n.backupNotRecognizedTitle,
                              style: BipaText.title.copyWith(color: colors.ink),
                            ),
                          ),
                          const SizedBox(height: BipaSpacing.s2),
                          Text(
                            problem == BackupProblem.fromNewerApp
                                ? l10n.backupNewerMessage
                                : l10n.backupNotRecognizedMessage,
                            style: BipaText.body.copyWith(color: colors.inkMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: BipaSpacing.s4),
            if (stacked || !showFirst)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showFirst) ...[first, const SizedBox(height: BipaSpacing.s2)],
                  fresh,
                ],
              )
            else
              Row(
                children: [
                  Expanded(child: first),
                  const SizedBox(width: BipaSpacing.s3),
                  Expanded(child: fresh),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// "Começar do zero" ou "Deixar de lado": o cartão some na hora e o aviso
/// ([message], com a data com o ano) traz o "Desfazer", que o devolve. O
/// arquivo só é adotado quando o aviso sai sem o "Desfazer"; até lá, ele
/// continua pendente.
void _setAside(BuildContext context, WidgetRef ref, String Function(AppLocalizations l10n, String date) message) {
  final backup = ref.read(backupProvider.notifier);
  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppLocalizations.of(context);
  final offer = backup.hideRestoreOffer();
  if (offer == null) return;
  final notice = showBipaToast(
    messenger,
    message(l10n, BackupLabels.fullDate(offer.createdAt)),
    actionLabel: l10n.undo,
    onAction: () => backup.bringBackRestoreOffer(offer),
    duration: BipaToastDuration.long,
  );
  unawaited(
    notice.closed.then((reason) {
      if (reason != SnackBarClosedReason.action) unawaited(backup.dismissRestoreOffer(offer));
    }),
  );
}

/// "Restaurar o backup de 12/10/2026?", com a data por extenso para o
/// leitor de tela.
class _OfferTitle extends StatelessWidget {
  const _OfferTitle({required this.offer, required this.style});

  final BackupInfo offer;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      header: true,
      label: l10n.backupRestoreTitle(BackupLabels.spokenDate(offer.createdAt)),
      excludeSemantics: true,
      child: Text(l10n.backupRestoreTitle(BackupLabels.fullDate(offer.createdAt)), style: style),
    );
  }
}

/// O cartão do backup de outro celular quando a casa já está em uso
/// (protótipo InicioBackupPendente, BK1): a pessoa bipou antes de responder,
/// e a pergunta fica até a resposta, sem ×, menor, para não disputar com a
/// casa: o título em 18/24 e os números numa linha de texto. Fica no lugar
/// do cartão do relatório de falhas.
///
/// "Restaurar" (neutro) sempre passa pela folha de confirmação, com os
/// números deste celular, porque já há o que perder. "Deixar de lado"
/// (secundário) tira o cartão com o aviso "O próximo grava por cima." e o
/// Desfazer; passado o aviso, o backup automático volta.
class PendingBackupCard extends ConsumerWidget {
  const PendingBackupCard({required this.offer, super.key});

  final BackupInfo offer;

  void _restore(BuildContext context, WidgetRef ref) => unawaited(
    showRestoreSheet(
      context,
      preparing: ref.read(backupProvider.notifier).prepareRestore(File(offer.path)),
      fromOtherPhone: true,
    ),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final summary = offer.manifest.summary;
    final stacked = MediaQuery.textScalerOf(context).scale(10) >= 15;

    final restore = NeutralButton(label: l10n.backupOfferRestore, onPressed: () => _restore(context, ref));
    final setAside = OutlinedButton(
      onPressed: () => _setAside(context, ref, (l10n, date) => l10n.backupOfferSetAsideNotice(date)),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: BipaSpacing.s3),
      ),
      child: Text(l10n.backupOfferSetAside, textAlign: TextAlign.center),
    );

    return Padding(
      padding: const EdgeInsets.only(top: BipaSpacing.s6),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(BipaRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  ExcludeSemantics(child: Icon(Icons.cloud_outlined, size: 16, color: colors.inkMuted)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l10n.backupOfferEyebrow,
                      style: BipaText.caption.copyWith(fontWeight: FontWeight.w700, color: colors.inkMuted),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: BipaSpacing.s3),
              _OfferTitle(
                offer: offer,
                style: BipaText.title.copyWith(
                  fontSize: 18,
                  height: 24 / 18,
                  fontWeight: FontWeight.w800,
                  color: colors.ink,
                ),
              ),
              const SizedBox(height: BipaSpacing.s1),
              Text(
                l10n.backupOfferSummary(
                  BackupLabels.count(summary.products),
                  summary.products,
                  BackupLabels.count(summary.prices),
                  summary.prices,
                  BackupLabels.count(summary.itemsAtHome),
                  summary.itemsAtHome,
                ),
                style: BipaText.label.copyWith(fontWeight: FontWeight.w400, height: 20 / 14, color: colors.inkMuted),
              ),
              const SizedBox(height: BipaSpacing.s4),
              if (stacked)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    restore,
                    const SizedBox(height: BipaSpacing.s2),
                    setAside,
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(child: restore),
                    const SizedBox(width: BipaSpacing.s2),
                    Expanded(child: setAside),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
