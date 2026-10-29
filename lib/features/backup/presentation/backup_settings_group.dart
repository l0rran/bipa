import 'dart:async';

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
    setState(() => _busy = _Busy.making);
    try {
      final info = await ref.read(backupProvider.notifier).createBackup();
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final last = ref.watch(backupProvider.select((state) => state.value?.lastBackup));
    final loaded = ref.watch(backupProvider.select((state) => !state.isLoading));
    final now = ref.watch(clockProvider)();

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(BipaRadius.lg),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _LastBackupRow(last: last, loaded: loaded, now: now, justMade: last != null && last.manifest.id == _justMade),
          Divider(color: colors.line),
          BackupActionRow(
            icon: Icons.cloud_upload_outlined,
            title: l10n.backupMakeNow,
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
        ],
      ),
    );
  }
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
