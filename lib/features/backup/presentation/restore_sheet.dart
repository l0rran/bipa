import 'dart:async';
import 'dart:io';

import 'package:bipa/core/design_system/bipa_metrics.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/design_system/bipa_typography.dart';
import 'package:bipa/core/design_system/components/bipa_loader.dart';
import 'package:bipa/core/design_system/components/bipa_toast.dart';
import 'package:bipa/core/errors/domain_exception.dart';
import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/features/backup/domain/backup_exception.dart';
import 'package:bipa/features/backup/domain/backup_manifest.dart';
import 'package:bipa/features/backup/domain/restore_backup.dart';
import 'package:bipa/features/backup/presentation/backup_files.dart';
import 'package:bipa/features/backup/presentation/backup_labels.dart';
import 'package:bipa/features/backup/presentation/backup_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Por que um backup não serve, na tela (protótipo RestaurarBackupResultado).
enum BackupProblem {
  /// Não é um `.bipa`, está incompleto ou não confere: "Escolher outro
  /// arquivo".
  notRecognized,

  /// De um Bipa mais novo: "Atualizar o Bipa".
  fromNewerApp;

  static BackupProblem of(Object error) => error is BackupException && error.code == DomainErrorCode.backupFromNewerApp
      ? BackupProblem.fromNewerApp
      : BackupProblem.notRecognized;
}

/// "Restaurar de um arquivo…": abre o seletor do Android e, escolhido o
/// arquivo, a folha que o confere e pede a confirmação.
Future<void> restoreFromFile(BuildContext context, WidgetRef ref) async {
  final picked = await ref.read(backupFilesProvider).pick();
  if (picked == null || !context.mounted) {
    await _discard(picked);
    return;
  }
  final backup = ref.read(backupProvider.notifier);
  // A conferência copia o que precisa; a cópia do seletor sai logo depois.
  final preparing = backup.prepareRestore(picked.file).whenComplete(() => _discard(picked));
  await showRestoreSheet(
    context,
    preparing: preparing,
    fileName: picked.name,
    onPickAnother: () => restoreFromFile(context, ref),
  );
}

Future<void> _discard(PickedBackup? picked) async {
  try {
    if (picked != null && picked.file.existsSync()) await picked.file.delete();
  } on FileSystemException {
    // Fica no cache do app, que o Android limpa.
  }
}

/// A folha de restauração (protótipo RestaurarBackup): "Conferindo o
/// arquivo" enquanto [preparing] não termina; depois, "Restaurar o backup de
/// 12/10/2025?" com os números do arquivo e os deste celular, ou, se o
/// arquivo não serve, o problema e a saída, no lugar da confirmação. Nada
/// muda no celular antes de "Substituir pelo backup".
///
/// [fromOtherPhone] é o `ultimo.bipa` do outro celular, aberto pela linha de
/// Ajustes ou pelo Início (protótipo AjustesBackupPendente): "De outro
/// celular" fica no lugar do nome do arquivo, e o aviso tem o ano.
///
/// Restaurado, a folha fecha e o aviso "Backup de 12/10 restaurado" traz o
/// "Desfazer" enquanto o aviso fica na tela, se [offerUndo].
Future<void> showRestoreSheet(
  BuildContext context, {
  required Future<PreparedRestore> preparing,
  String? fileName,
  VoidCallback? onPickAnother,
  bool offerUndo = true,
  bool fromOtherPhone = false,
}) {
  // A conferência pode falhar antes de a folha subir e ouvir o resultado: a
  // folha ainda recebe o erro, mas ele não escapa como erro sem tratamento.
  preparing.ignore();
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (_) => RestoreSheet(
      preparing: preparing,
      fileName: fileName,
      onPickAnother: onPickAnother,
      offerUndo: offerUndo,
      fromOtherPhone: fromOtherPhone,
    ),
  );
}

/// Tira as fotos antigas da memória: depois de restaurar (ou desfazer), as
/// fotos dos produtos têm o mesmo caminho e outro conteúdo.
void clearProductImageCache() {
  PaintingBinding.instance.imageCache
    ..clear()
    ..clearLiveImages();
}

/// Troca os dados pelos de [prepared] e avisa, com o "Desfazer" se
/// [offerUndo]. O aviso tem o ano quando o backup é do outro celular
/// ([fromOtherPhone]). Devolve `false` se a troca falhou (já avisado).
///
/// A reserva do "Desfazer" vive enquanto o aviso vive (BK2): o aviso segue a
/// regra do tempo do `bipa-toast` (espera a pessoa com leitor de tela, estica
/// com o "Tempo para agir" e para com o dedo em cima), e a reserva só é
/// descartada quando ele sai sem o "Desfazer". Sem "Desfazer" a oferecer, ela
/// é descartada na hora.
Future<bool> applyRestoreAndNotify({
  required BackupController backup,
  required PreparedRestore prepared,
  required ScaffoldMessengerState messenger,
  required AppLocalizations l10n,
  bool offerUndo = true,
  bool fromOtherPhone = false,
}) async {
  try {
    await backup.applyRestore(prepared);
  } on Exception {
    showBipaToast(messenger, l10n.backupRestoreFailed);
    return false;
  }
  final epoch = backup.restoreEpoch;
  clearProductImageCache();
  final createdAt = prepared.manifest.createdAt;
  final restored = l10n.backupRestored(
    fromOtherPhone ? BackupLabels.fullDate(createdAt) : BackupLabels.date(createdAt),
  );
  if (!offerUndo) {
    showBipaToast(messenger, restored, duration: BipaToastDuration.long);
    unawaited(backup.discardRestoreUndo(epoch));
    return true;
  }
  final notice = showBipaToast(
    messenger,
    restored,
    actionLabel: l10n.undo,
    onAction: () => unawaited(() async {
      final bool undone;
      try {
        undone = await backup.undoRestore();
      } on Exception {
        showBipaToast(messenger, l10n.backupRestoreFailed);
        return;
      }
      clearProductImageCache();
      if (!undone) showBipaToast(messenger, l10n.backupUndoExpired);
    }()),
    duration: BipaToastDuration.long,
  );
  // O aviso saiu sem o "Desfazer" (o tempo acabou, a pessoa o dispensou ou
  // outro aviso tomou o lugar): ninguém mais pode desfazer.
  unawaited(
    notice.closed.then((reason) {
      if (reason != SnackBarClosedReason.action) unawaited(backup.discardRestoreUndo(epoch));
    }),
  );
  return true;
}

class RestoreSheet extends ConsumerStatefulWidget {
  const RestoreSheet({
    required this.preparing,
    this.fileName,
    this.onPickAnother,
    this.offerUndo = true,
    this.fromOtherPhone = false,
    super.key,
  });

  final Future<PreparedRestore> preparing;

  /// O nome do arquivo escolhido, embaixo de "Conferindo o arquivo".
  final String? fileName;

  /// "Escolher outro arquivo" abre o seletor de novo; sem ele, o botão não
  /// aparece.
  final VoidCallback? onPickAnother;
  final bool offerUndo;

  /// O backup do outro celular: "De outro celular" embaixo do título.
  final bool fromOtherPhone;

  @override
  ConsumerState<RestoreSheet> createState() => _RestoreSheetState();
}

class _RestoreSheetState extends ConsumerState<RestoreSheet> {
  /// Lido no `initState`: no `dispose`, o `ref` não vale mais.
  late final BackupController _backup;
  PreparedRestore? _prepared;
  BackupProblem? _problem;
  var _restoring = false;

  /// A troca começou: fechar a folha não cancela mais nada.
  var _applied = false;

  /// O esqueleto dos números só aparece se a conferência passar de 200 ms.
  var _showSkeleton = false;
  Timer? _skeletonTimer;

  @override
  void initState() {
    super.initState();
    _backup = ref.read(backupProvider.notifier);
    _skeletonTimer = Timer(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _showSkeleton = true);
    });
    unawaited(
      widget.preparing.then(
        (prepared) {
          if (!mounted) {
            // Fechada antes de conferir: a cópia conferida sai.
            unawaited(_backup.cancelRestore(prepared));
            return;
          }
          setState(() => _prepared = prepared);
        },
        onError: (Object error) {
          if (mounted) setState(() => _problem = BackupProblem.of(error));
        },
      ),
    );
  }

  @override
  void dispose() {
    _skeletonTimer?.cancel();
    final prepared = _prepared;
    // Cancelar, arrastar para baixo ou voltar: nada muda no celular.
    if (prepared != null && !_applied) unawaited(_backup.cancelRestore(prepared));
    super.dispose();
  }

  Future<void> _replace(PreparedRestore prepared) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    setState(() {
      _restoring = true;
      _applied = true;
    });
    await applyRestoreAndNotify(
      backup: _backup,
      prepared: prepared,
      messenger: messenger,
      l10n: l10n,
      offerUndo: widget.offerUndo,
      fromOtherPhone: widget.fromOtherPhone,
    );
    if (mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final problem = _problem;
    final prepared = _prepared;
    return PopScope(
      // Restaurando, a folha não fecha: o Cancelar saiu.
      canPop: !_restoring,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(BipaSpacing.s6, 0, BipaSpacing.s6, BipaSpacing.s6),
        child: problem != null
            ? _ProblemContent(
                problem: problem,
                onPickAnother: widget.onPickAnother == null
                    ? null
                    : () {
                        Navigator.of(context).pop();
                        widget.onPickAnother!();
                      },
                onUpdate: () => unawaited(ref.read(backupFilesProvider).openStorePage()),
              )
            : _ConfirmContent(
                prepared: prepared,
                fileName: widget.fileName,
                fromOtherPhone: widget.fromOtherPhone,
                showSkeleton: _showSkeleton,
                restoring: _restoring,
                onReplace: prepared == null ? null : () => _replace(prepared),
              ),
      ),
    );
  }
}

/// Conferindo, conferido ou restaurando: a mesma folha, que muda no lugar.
class _ConfirmContent extends StatelessWidget {
  const _ConfirmContent({
    required this.prepared,
    required this.fileName,
    required this.fromOtherPhone,
    required this.showSkeleton,
    required this.restoring,
    required this.onReplace,
  });

  final PreparedRestore? prepared;
  final String? fileName;
  final bool fromOtherPhone;
  final bool showSkeleton;
  final bool restoring;
  final VoidCallback? onReplace;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final prepared = this.prepared;
    // A origem fica embaixo do título nos dois momentos; o nome do arquivo,
    // só enquanto confere.
    final source = fromOtherPhone ? l10n.backupFromOtherPhone : (prepared == null ? fileName : null);
    final body = BipaText.body.copyWith(color: colors.ink);
    final note = BipaText.label.copyWith(fontWeight: FontWeight.w500, height: 20 / 14, color: colors.inkMuted);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (prepared == null) ...[
          Semantics(
            header: true,
            liveRegion: true,
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: BipaSpacing.s3,
              children: [
                Text(l10n.backupChecking, style: BipaText.title.copyWith(color: colors.ink)),
                const BipaLoader(height: 18),
              ],
            ),
          ),
        ] else
          Semantics(
            header: true,
            // O leitor de tela ouve a data por extenso ("12 de outubro de
            // 2025").
            label: l10n.backupRestoreTitle(BackupLabels.spokenDate(prepared.manifest.createdAt)),
            excludeSemantics: true,
            child: Text(
              l10n.backupRestoreTitle(BackupLabels.fullDate(prepared.manifest.createdAt)),
              style: BipaText.title.copyWith(color: colors.ink),
            ),
          ),
        if (source != null && source.isNotEmpty) ...[
          const SizedBox(height: BipaSpacing.s1),
          Text(
            source,
            style: BipaText.label.copyWith(fontWeight: FontWeight.w500, color: colors.inkMuted),
          ),
        ],
        const SizedBox(height: BipaSpacing.s4),
        Divider(color: colors.line),
        const SizedBox(height: BipaSpacing.s4),
        if (prepared == null)
          ExcludeSemantics(child: _FactsSkeleton(visible: showSkeleton))
        else ...[
          BackupFacts(summary: prepared.backup),
          const SizedBox(height: BipaSpacing.s3),
          _CurrentLine(prepared: prepared),
          const SizedBox(height: BipaSpacing.s4),
          Text(l10n.backupReplaceWarning, style: body),
          // O que a troca leva embora, numa linha própria: um backup mais
          // velho que a casa parece inofensivo pelos números (BK3).
          if (prepared.losesNewerData) ...[
            const SizedBox(height: BipaSpacing.s2),
            Text(
              l10n.backupLosesNewer(BackupLabels.fullDate(prepared.manifest.createdAt)),
              style: note.copyWith(fontWeight: FontWeight.w700, color: colors.ink),
            ),
          ],
          if (prepared.adjustedItems > 0) ...[
            const SizedBox(height: BipaSpacing.s2),
            Text(l10n.backupAdjusted(prepared.adjustedItems), style: note),
          ],
        ],
        const SizedBox(height: BipaSpacing.s6),
        NeutralButton(
          label: l10n.backupReplace,
          busyLabel: l10n.backupRestoring,
          busy: restoring,
          onPressed: restoring ? null : onReplace,
        ),
        if (!restoring) ...[
          const SizedBox(height: BipaSpacing.s2),
          TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            child: Text(l10n.cancel),
          ),
        ],
      ],
    );
  }
}

/// "Neste celular agora: **230** produtos, **1.452** preços e **61** itens
/// em casa.", os mesmos três números do arquivo, na mesma ordem (BK3).
class _CurrentLine extends StatelessWidget {
  const _CurrentLine({required this.prepared});

  final PreparedRestore prepared;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final current = prepared.current;
    final products = BackupLabels.count(current.products);
    final prices = BackupLabels.count(current.prices);
    final items = BackupLabels.count(current.itemsAtHome);
    final text = l10n.backupCurrent(products, current.products, prices, current.prices, items, current.itemsAtHome);
    final style = BipaText.label.copyWith(fontWeight: FontWeight.w500, height: 20 / 14, color: colors.inkMuted);
    final bold = style.copyWith(fontWeight: FontWeight.w800, color: colors.ink);
    return Text.rich(TextSpan(style: style, children: boldParts(text, [products, prices, items], bold)));
  }
}

/// [text] com cada um de [parts], procurados na ordem, em [bold]: os números
/// em `ink` no meio de uma frase em `ink-muted`.
List<TextSpan> boldParts(String text, List<String> parts, TextStyle bold) {
  final spans = <TextSpan>[];
  var from = 0;
  for (final part in parts) {
    final at = text.indexOf(part, from);
    if (at < 0) continue;
    if (at > from) spans.add(TextSpan(text: text.substring(from, at)));
    spans.add(TextSpan(text: part, style: bold));
    from = at + part.length;
  }
  if (from < text.length) spans.add(TextSpan(text: text.substring(from)));
  return spans;
}

/// O arquivo não serve: o ícone em `alert-text`, o problema, a saída num
/// botão secundário e "Fechar" só texto. Fica no lugar da confirmação.
class _ProblemContent extends StatelessWidget {
  const _ProblemContent({required this.problem, required this.onPickAnother, required this.onUpdate});

  final BackupProblem problem;
  final VoidCallback? onPickAnother;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final (icon, title, message, exit, onExit) = switch (problem) {
      BackupProblem.notRecognized => (
        Icons.broken_image_outlined,
        l10n.backupNotRecognizedTitle,
        l10n.backupNotRecognizedMessage,
        l10n.backupPickAnother,
        onPickAnother,
      ),
      BackupProblem.fromNewerApp => (
        Icons.system_update_outlined,
        l10n.backupNewerTitle,
        l10n.backupNewerMessage,
        l10n.backupUpdateApp,
        onUpdate,
      ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          liveRegion: true,
          container: true,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(child: Icon(icon, size: 28, color: colors.alertText)),
              const SizedBox(width: BipaSpacing.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(title, style: BipaText.title.copyWith(color: colors.ink)),
                    ),
                    const SizedBox(height: BipaSpacing.s2),
                    Text(message, style: BipaText.body.copyWith(color: colors.inkMuted)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: BipaSpacing.s6),
        if (onExit != null)
          OutlinedButton(
            onPressed: onExit,
            child: Text(exit, textAlign: TextAlign.center),
          ),
        const SizedBox(height: BipaSpacing.s2),
        TextButton(
          onPressed: () => Navigator.of(context).maybePop(),
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          child: Text(l10n.backupClose),
        ),
      ],
    );
  }
}

/// O botão neutro (`ink`) em toda a largura. Ocupado, o rótulo vira o
/// indicador de carregamento em `ground`, sem mudar de largura, e o leitor
/// de tela ouve [busyLabel].
class NeutralButton extends StatelessWidget {
  const NeutralButton({required this.label, required this.onPressed, this.busy = false, this.busyLabel, super.key});

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final String? busyLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: colors.ink,
        foregroundColor: colors.surface,
        // Ocupado, o botão continua cheio; desabilitado enquanto confere, ele
        // fica apagado com o mesmo rótulo.
        disabledBackgroundColor: busy ? colors.ink : colors.surfaceSunken,
        disabledForegroundColor: busy ? colors.ground : colors.inkMuted,
        minimumSize: const Size(64, 52),
      ),
      child: busy
          ? BipaLoader(color: colors.ground, height: 20, semanticLabel: busyLabel)
          : Text(label, textAlign: TextAlign.center),
    );
  }
}

/// Os três números de um backup (`bipa-facts`): produtos, preços e itens em
/// casa, com o rótulo embaixo, separados por fios. Com letra grande, um
/// embaixo do outro, cada um numa linha.
class BackupFacts extends StatelessWidget {
  const BackupFacts({required this.summary, super.key});

  final BackupSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final facts = [
      (BackupLabels.count(summary.products), l10n.backupProducts(summary.products)),
      (BackupLabels.count(summary.prices), l10n.backupPrices(summary.prices)),
      (BackupLabels.count(summary.itemsAtHome), l10n.backupItemsAtHome(summary.itemsAtHome)),
    ];
    final valueStyle = BipaText.number.copyWith(fontSize: 22, height: 28 / 22, color: colors.ink);
    final labelStyle = BipaText.label.copyWith(fontWeight: FontWeight.w500, color: colors.inkMuted);

    // A 150% ou mais, três colunas não cabem "1.380" e "itens em casa".
    if (MediaQuery.textScalerOf(context).scale(10) >= 15) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (value, label) in facts)
            Semantics(
              label: '$value $label',
              excludeSemantics: true,
              child: Padding(
                padding: const EdgeInsets.only(bottom: BipaSpacing.s1),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: value, style: valueStyle),
                      TextSpan(text: ' $label', style: labelStyle),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, (value, label)) in facts.indexed) ...[
            if (index > 0) ...[
              VerticalDivider(color: colors.line, width: 1, thickness: 1),
              const SizedBox(width: BipaSpacing.s3),
            ],
            Expanded(
              child: Semantics(
                label: '$value $label',
                excludeSemantics: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value, style: valueStyle),
                    Text(label, style: labelStyle),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// O lugar dos números enquanto o arquivo é conferido (`bipa-skeleton`):
/// blocos em `surface-sunken`, que só aparecem depois de 200 ms.
class _FactsSkeleton extends StatelessWidget {
  const _FactsSkeleton({required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    Widget block(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: colors.surfaceSunken, borderRadius: BorderRadius.circular(BipaRadius.sm)),
    );
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: BipaMotion.base,
      child: Row(
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: BipaSpacing.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  block(double.infinity, 28),
                  const SizedBox(height: BipaSpacing.s2),
                  block(64, 12),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
