import 'dart:async';
import 'dart:io';

import 'package:bipa/core/design_system/bipa_metrics.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/design_system/bipa_typography.dart';
import 'package:bipa/core/design_system/components/bipa_loader.dart';
import 'package:bipa/core/design_system/components/bipa_toast.dart';
import 'package:bipa/core/di/core_providers.dart';
import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/features/backup/domain/backup_info.dart';
import 'package:bipa/features/backup/presentation/backup_files.dart';
import 'package:bipa/features/backup/presentation/backup_labels.dart';
import 'package:bipa/features/backup/presentation/backup_providers.dart';
import 'package:bipa/features/backup/presentation/restore_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// O que está em andamento no grupo.
enum _Busy { none, making, saving }

/// O cartão do grupo "Backup" de Ajustes (protótipo AjustesBackup, ADR 0023,
/// seção 5): o último backup como número, com a frase de que ele é
/// automático e vai para um celular novo pelo backup do Google, e as linhas
/// de ação. Nenhuma cor de destaque: Ajustes continua neutro.
///
/// Um último backup maior que os 25 MB do backup do Google troca a frase
/// pelo tamanho e sugere "Salvar uma cópia…".
///
/// Com o backup de outro celular à espera de resposta (protótipo
/// AjustesBackupPendente, BK1): a linha do último backup diz a origem, com o
/// ano, e restaura ao toque; "Fazer backup agora" diz que o automático está
/// pausado e pergunta antes de gravar por cima; "Salvar uma cópia…" grava só
/// a cópia.
class BackupSettingsCard extends ConsumerStatefulWidget {
  const BackupSettingsCard({super.key});

  @override
  ConsumerState<BackupSettingsCard> createState() => _BackupSettingsCardState();
}

class _BackupSettingsCardState extends ConsumerState<BackupSettingsCard> {
  var _busy = _Busy.none;

  /// O backup que "Fazer backup agora" acabou de gravar: o valor passa a
  /// "agora".
  String? _justMade;

  Future<void> _makeNow() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final last = ref.read(backupProvider).value?.lastBackup;
    final pending = last != null && !last.madeHere;
    // Gravar por cima do backup do outro celular é apagá-lo: pergunta antes.
    if (pending && !await confirmReplacePending(context, last)) return;
    if (!mounted) return;
    setState(() => _busy = _Busy.making);
    try {
      final info = await ref.read(backupProvider.notifier).createBackup(replacePending: pending);
      if (info == null) {
        showBipaToast(messenger, l10n.backupNothingYet);
      } else if (mounted) {
        // Sem aviso: o valor muda para "agora", e o leitor de tela o ouve.
        setState(() => _justMade = info.manifest.id);
      }
    } on Exception {
      showBipaToast(messenger, l10n.backupFailed);
    } finally {
      if (mounted) setState(() => _busy = _Busy.none);
    }
  }

  /// "Salvar uma cópia…": grava um backup novo e abre o "Salvar como" do
  /// Android com o nome `bipa-2026-10-29.bipa`.
  Future<void> _saveCopy() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final backup = ref.read(backupProvider.notifier);
    setState(() => _busy = _Busy.saving);
    try {
      final saved = await ref.read(backupFilesProvider).save((destination) async {
        final manifest = await backup.saveCopy(destination);
        return backupFileName(manifest.createdAt);
      });
      if (saved) showBipaToast(messenger, l10n.backupCopySaved);
    } on Exception {
      showBipaToast(messenger, l10n.backupCopyFailed);
    } finally {
      if (mounted) setState(() => _busy = _Busy.none);
    }
  }

  /// O toque na linha do backup de outro celular: a folha de confirmação com
  /// esse arquivo, sem o seletor do Android, que não vê a pasta do app.
  Future<void> _restorePending(BackupInfo last) => showRestoreSheet(
    context,
    preparing: ref.read(backupProvider.notifier).prepareRestore(File(last.path)),
    fromOtherPhone: true,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final last = ref.watch(backupProvider.select((state) => state.value?.lastBackup));
    final loaded = ref.watch(backupProvider.select((state) => !state.isLoading));
    final now = ref.watch(clockProvider)();
    final pending = last != null && !last.madeHere;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(BipaRadius.lg),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (pending)
            _PendingBackupRow(last: last, onTap: _busy == _Busy.none ? () => unawaited(_restorePending(last)) : null)
          else
            _LastBackupRow(
              last: last,
              loaded: loaded,
              now: now,
              justMade: last != null && last.manifest.id == _justMade,
            ),
          Divider(color: colors.line),
          BackupActionRow(
            icon: Icons.cloud_upload_outlined,
            title: l10n.backupMakeNow,
            subtitle: pending ? _automaticState(l10n, last, now) : null,
            busyLabel: l10n.backupMaking,
            busy: _busy == _Busy.making,
            onTap: _busy == _Busy.none ? _makeNow : null,
          ),
          Divider(color: colors.line),
          BackupActionRow(
            icon: Icons.ios_share_rounded,
            title: l10n.backupSaveCopy,
            subtitle: l10n.backupSaveCopySubtitle,
            busyLabel: l10n.backupMaking,
            busy: _busy == _Busy.saving,
            onTap: _busy == _Busy.none ? _saveCopy : null,
          ),
          Divider(color: colors.line),
          BackupActionRow(
            icon: Icons.file_open_outlined,
            title: l10n.backupRestoreFromFile,
            onTap: _busy == _Busy.none ? () => unawaited(restoreFromFile(context, ref)) : null,
          ),
        ],
      ),
    );
  }
}

/// O estado do automático embaixo de "Fazer backup agora", com o backup de
/// outro celular no lugar: pausado até a resposta, ou, no dia em que ele foi
/// deixado de lado, de volta amanhã (BK6). Passado esse dia, o diário grava
/// na próxima volta ao app, e a linha não diz nada.
String? _automaticState(AppLocalizations l10n, BackupInfo pending, DateTime now) {
  final setAside = pending.setAsideAt;
  if (setAside == null) return l10n.backupMakeNowPaused;
  final (day, today) = (setAside.toLocal(), now.toLocal());
  final sameDay = day.year == today.year && day.month == today.month && day.day == today.day;
  return sameDay ? l10n.backupMakeNowResumesTomorrow : null;
}

/// A linha que só informa: "Último backup", a frase e o valor à direita, o
/// dia grande e a hora embaixo.
class _LastBackupRow extends StatelessWidget {
  const _LastBackupRow({required this.last, required this.loaded, required this.now, required this.justMade});

  final BackupInfo? last;
  final bool loaded;
  final DateTime now;
  final bool justMade;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final last = this.last;
    final (String day, String? time) = switch (last) {
      _ when justMade => (l10n.backupNow, null),
      null => (l10n.backupNever, null),
      final info => (BackupLabels.day(l10n, info.createdAt, now), BackupLabels.time(info.createdAt)),
    };
    final tooBig = last != null && !last.fitsAndroidAutoBackup;
    final subtitle = tooBig ? l10n.backupTooBig(BackupLabels.megabytes(last.size)) : l10n.backupLastSubtitle;
    final when = time == null ? day : '$day, $time';

    return Semantics(
      container: true,
      // Muda para "agora" depois de "Fazer backup agora": o leitor de tela
      // ouve sem aviso na tela.
      liveRegion: true,
      label: '${l10n.backupLastSemantics(when)}. $subtitle',
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: BipaSpacing.s4, vertical: BipaSpacing.s4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: BipaSpacing.s1),
                child: Icon(Icons.history_rounded, size: 24, color: colors.ink),
              ),
              const SizedBox(width: BipaSpacing.s4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.backupLastTitle, style: BipaText.bodyLarge.copyWith(color: colors.ink)),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: BipaText.label.copyWith(
                        fontWeight: FontWeight.w500,
                        height: 20 / 14,
                        // O aviso do tamanho fica em `ink`: é o que pede uma
                        // ação, sem cor de destaque.
                        color: tooBig ? colors.ink : colors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (loaded) ...[
                const SizedBox(width: BipaSpacing.s3),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(day, style: BipaText.number.copyWith(fontSize: 17, color: colors.ink)),
                    if (time != null)
                      Text(
                        time,
                        style: BipaText.caption.copyWith(
                          color: colors.inkMuted,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A linha do último backup quando ele é de outro celular e espera resposta
/// (protótipo AjustesBackupPendente): a mesma linha, agora botão, com o
/// ícone do celular com a seta, a origem na frase ("De outro celular. Toque
/// para restaurar.") e o dia grande com o ano embaixo.
class _PendingBackupRow extends StatelessWidget {
  const _PendingBackupRow({required this.last, required this.onTap});

  final BackupInfo last;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final createdAt = last.createdAt;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: l10n.backupLastPendingSemantics(BackupLabels.spokenDate(createdAt)),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        splashFactory: NoSplash.splashFactory,
        highlightColor: colors.surfaceSunken,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: BipaSpacing.s4, vertical: BipaSpacing.s4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: BipaSpacing.s1),
                  child: Icon(Icons.install_mobile, size: 24, color: colors.ink),
                ),
                const SizedBox(width: BipaSpacing.s4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.backupLastTitle, style: BipaText.bodyLarge.copyWith(color: colors.ink)),
                      const SizedBox(height: 2),
                      Text(
                        l10n.backupLastFromOtherPhone,
                        style: BipaText.label.copyWith(
                          fontWeight: FontWeight.w500,
                          height: 20 / 14,
                          color: colors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: BipaSpacing.s3),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      BackupLabels.date(createdAt),
                      style: BipaText.number.copyWith(fontSize: 17, color: colors.ink),
                    ),
                    Text(
                      BackupLabels.year(createdAt),
                      style: BipaText.caption.copyWith(
                        color: colors.inkMuted,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Fazer backup agora" com o backup de outro celular pendente: o diálogo
/// das ações que apagam, com a data, os números do que some e os botões
/// empilhados, porque "Apagar e fazer backup" não cabe ao lado de
/// "Cancelar". Devolve `true` só quando a pessoa confirma.
Future<bool> confirmReplacePending(BuildContext context, BackupInfo pending) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      final l10n = AppLocalizations.of(context);
      final colors = context.colors;
      final summary = pending.manifest.summary;
      final date = BackupLabels.fullDate(pending.createdAt);
      final products = BackupLabels.count(summary.products);
      final prices = BackupLabels.count(summary.prices);
      final items = BackupLabels.count(summary.itemsAtHome);
      final body = l10n.backupReplacePendingBody(
        date,
        products,
        summary.products,
        prices,
        summary.prices,
        items,
        summary.itemsAtHome,
      );
      final style = BipaText.body.copyWith(color: colors.inkMuted);
      final bold = style.copyWith(fontWeight: FontWeight.w700, color: colors.ink);
      return AlertDialog(
        title: Text(l10n.backupReplacePendingTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text.rich(TextSpan(style: style, children: boldParts(body, [date, products, prices, items], bold))),
              const SizedBox(height: BipaSpacing.s6),
              NeutralButton(label: l10n.backupReplacePendingConfirm, onPressed: () => Navigator.of(context).pop(true)),
              const SizedBox(height: BipaSpacing.s2),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                child: Text(l10n.cancel),
              ),
            ],
          ),
        ),
      );
    },
  );
  return confirmed ?? false;
}

/// Uma linha de ação de Ajustes: ícone de 24 em `ink`, o título com a ação e,
/// se houver, uma linha embaixo. Sem seta nem cor. Ocupada, o ícone vira o
/// indicador de carregamento.
class BackupActionRow extends StatelessWidget {
  const BackupActionRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.busy = false,
    this.busyLabel,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool busy;

  /// O que o leitor de tela ouve enquanto a linha está ocupada.
  final String? busyLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final subtitle = this.subtitle;
    return Semantics(
      button: true,
      enabled: onTap != null || busy,
      label: busy && busyLabel != null ? '$title. $busyLabel' : null,
      child: InkWell(
        onTap: busy ? null : onTap,
        splashFactory: NoSplash.splashFactory,
        highlightColor: colors.surfaceSunken,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: BipaSpacing.s4, vertical: BipaSpacing.s3),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 24,
                  child: Center(child: busy ? const BipaLoader(height: 18) : Icon(icon, size: 24, color: colors.ink)),
                ),
                const SizedBox(width: BipaSpacing.s4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, style: BipaText.bodyLarge.copyWith(color: colors.ink)),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: BipaText.label.copyWith(
                            fontWeight: FontWeight.w500,
                            height: 20 / 14,
                            color: colors.inkMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
