import 'dart:async';
import 'dart:io';

import 'package:bipa/core/design_system/bipa_metrics.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/design_system/bipa_typography.dart';
import 'package:bipa/core/design_system/components/bipa_toast.dart';
import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/features/backup/domain/backup_info.dart';
import 'package:bipa/features/backup/domain/backup_manifest.dart';
import 'package:bipa/features/backup/domain/restore_backup.dart';
import 'package:bipa/features/backup/presentation/backup_files.dart';
import 'package:bipa/features/backup/presentation/backup_labels.dart';
import 'package:bipa/features/backup/presentation/backup_providers.dart';
import 'package:bipa/features/backup/presentation/restore_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// O cartão "Backup encontrado" do Início no celular novo (protótipo
/// InicioBackupEncontrado, ADR 0023, B1): o Android trouxe o `ultimo.bipa`
/// do celular antigo, e o banco está vazio. Fica no lugar do convite da casa
/// vazia, com os números do arquivo, "Restaurar" (neutro) e "Começar do
/// zero" (secundário). Nada é restaurado sozinho.
///
/// "Restaurar" confere e troca com o botão carregando, sem a folha de
/// confirmação, porque a casa vazia não perde nada; se já há o que perder,
/// passa pela folha. "Começar do zero" tira o cartão com Desfazer por 10 s;
/// o arquivo continua restaurável pelos Ajustes até o próximo backup diário.
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
    if (prepared.current == BackupSummary.empty) {
      // Pronto, o cartão some com a oferta e o Início se enche.
      await applyRestoreAndNotify(
        backup: backup,
        prepared: prepared,
        messenger: messenger,
        l10n: l10n,
        offerUndo: false,
      );
      if (mounted) setState(() => _restoring = false);
      return;
    }
    if (!mounted) {
      await backup.cancelRestore(prepared);
      return;
    }
    setState(() => _restoring = false);
    await showRestoreSheet(context, preparing: Future.value(prepared));
  }

  /// "Começar do zero": o cartão some na hora; o arquivo só é adotado quando
  /// o aviso sai sem o "Desfazer".
  void _startFresh() {
    final backup = ref.read(backupProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final offer = backup.hideRestoreOffer();
    if (offer == null) return;
    final notice = showBipaToast(
      messenger,
      l10n.backupOfferDismissed(BackupLabels.date(offer.createdAt)),
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
              Semantics(
                header: true,
                child: Text(
                  l10n.backupRestoreTitle(BackupLabels.date(offer.createdAt)),
                  style: BipaText.title.copyWith(fontWeight: FontWeight.w800, color: colors.ink),
                ),
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
