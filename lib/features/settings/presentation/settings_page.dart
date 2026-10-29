import 'package:bipa/core/crash_reporting/crash_reporting.dart';
import 'package:bipa/core/crash_reporting/crash_reporting_providers.dart';
import 'package:bipa/core/design_system/bipa_metrics.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/design_system/bipa_typography.dart';
import 'package:bipa/core/design_system/components/bipa_toast.dart';
import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/features/backup/presentation/backup_settings_group.dart';
import 'package:bipa/features/settings/presentation/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Os Ajustes (protótipo "Ajustes", ADR 0025): a tela mínima, aberta pela
/// engrenagem do Início. "Backup" vem primeiro (protótipo AjustesBackup,
/// ADR 0023, seção 5). "Privacidade" tem o interruptor do relatório de
/// falhas, o único lugar para mudar de ideia nos dois sentidos, com o que vai
/// e o que nunca vai logo abaixo; "Sobre o Bipa" traz a versão.
///
/// Em build sem DSN o relatório não existe, e a seção "Privacidade" some.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final available = ref.watch(crashReportingAvailableProvider);
    final version = ref.watch(appVersionProvider).value;

    return Scaffold(
      backgroundColor: colors.ground,
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          BipaSpacing.s4,
          MediaQuery.paddingOf(context).top + BipaSpacing.s4,
          BipaSpacing.s4,
          MediaQuery.paddingOf(context).bottom + BipaSpacing.s8,
        ),
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: IconButton.filled(
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              style: IconButton.styleFrom(
                backgroundColor: colors.surface,
                foregroundColor: colors.ink,
                fixedSize: const Size.square(48),
              ),
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            ),
          ),
          const SizedBox(height: BipaSpacing.s4),
          Semantics(
            header: true,
            child: Text(l10n.settingsTitle, style: BipaText.headline.copyWith(color: colors.ink)),
          ),
          const SizedBox(height: BipaSpacing.s6),
          _Group(label: l10n.settingsBackup, child: const BackupSettingsCard()),
          if (available) ...[
            const SizedBox(height: BipaSpacing.s6),
            _Group(label: l10n.settingsPrivacy, child: const _CrashReportingCard()),
          ],
          const SizedBox(height: BipaSpacing.s6),
          _Group(
            label: l10n.settingsAbout,
            child: _Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: BipaSpacing.s4, vertical: BipaSpacing.s4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(l10n.settingsVersion, style: BipaText.bodyLarge.copyWith(color: colors.ink)),
                    ),
                    const SizedBox(width: BipaSpacing.s3),
                    if (version != null)
                      Text(
                        version,
                        style: BipaText.body.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colors.inkMuted,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// O rótulo em versalete e, embaixo, o cartão do grupo.
class _Group extends StatelessWidget {
  const _Group({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(BipaSpacing.s1, 0, BipaSpacing.s1, BipaSpacing.s2),
          child: Semantics(
            header: true,
            child: Text(
              label.toUpperCase(),
              style: BipaText.caption.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 12 * 0.04,
                color: context.colors.inkMuted,
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(BipaRadius.lg),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

/// O interruptor do relatório de falhas e, aberto embaixo, o que vai e o que
/// nunca vai: é a explicação que a LGPD pede, num lugar só.
class _CrashReportingCard extends ConsumerWidget {
  const _CrashReportingCard();

  Future<void> _change(BuildContext context, WidgetRef ref, {required bool granted}) async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = AppLocalizations.of(context).settingsCrashFailed;
    final consent = ref.read(crashReportingConsentProvider.notifier);
    try {
      await (granted ? consent.grant() : consent.deny());
    } on Exception {
      // Sem o aviso, o interruptor não mudaria e nada diria por quê.
      showBipaToast(messenger, failed);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final granted = ref.watch(crashReportingConsentProvider) == CrashReportingConsent.granted;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            value: granted,
            onChanged: (value) => _change(context, ref, granted: value),
            contentPadding: const EdgeInsets.symmetric(horizontal: BipaSpacing.s4, vertical: BipaSpacing.s1),
            title: Text(l10n.settingsCrashTitle, style: BipaText.bodyLarge.copyWith(color: colors.ink)),
            subtitle: Text(
              l10n.settingsCrashSubtitle,
              style: BipaText.label.copyWith(fontWeight: FontWeight.w500, color: colors.inkMuted),
            ),
          ),
          Divider(color: colors.line),
          Padding(
            padding: const EdgeInsets.fromLTRB(BipaSpacing.s4, BipaSpacing.s3, BipaSpacing.s4, BipaSpacing.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Sent(
                  title: l10n.settingsCrashSentTitle,
                  icon: Icons.check_rounded,
                  lines: [l10n.settingsCrashSent1, l10n.settingsCrashSent2, l10n.settingsCrashSent3],
                ),
                const SizedBox(height: BipaSpacing.s3),
                _Sent(
                  title: l10n.settingsCrashNeverTitle,
                  icon: Icons.close_rounded,
                  lines: [l10n.settingsCrashNever1, l10n.settingsCrashNever2, l10n.settingsCrashNever3],
                ),
                const SizedBox(height: BipaSpacing.s3),
                Text(
                  l10n.settingsCrashNote,
                  style: BipaText.label.copyWith(fontWeight: FontWeight.w500, color: colors.inkMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Um grupo do que vai ou do que nunca vai: o título e as linhas, cada uma
/// com o ícone de visto ou de x. O título já diz o sentido; o ícone só
/// reforça, por isso o leitor de tela o pula.
class _Sent extends StatelessWidget {
  const _Sent({required this.title, required this.icon, required this.lines});

  final String title;
  final IconData icon;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: BipaText.label.copyWith(color: colors.ink)),
        ),
        const SizedBox(height: BipaSpacing.s2),
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: ExcludeSemantics(child: Icon(icon, size: 18, color: colors.inkMuted)),
                ),
                const SizedBox(width: BipaSpacing.s2),
                Expanded(
                  child: Text(
                    line,
                    style: BipaText.label.copyWith(fontWeight: FontWeight.w500, height: 20 / 14, color: colors.ink),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
