import 'package:bipa/core/crash_reporting/crash_reporting_providers.dart';
import 'package:bipa/core/design_system/bipa_metrics.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/design_system/bipa_typography.dart';
import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/features/settings/presentation/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A pergunta do relatório de falhas no Início (protótipo
/// "InicioRelatorioFalhas", ADR 0025): um cartão neutro, uma vez só, depois
/// da primeira compra terminada e só em build com DSN.
///
/// "Mandar" e "Não mandar" têm o mesmo peso e nada vem marcado. O × fecha e
/// conta como "não", então o cartão não volta. Quem muda de ideia depois usa
/// o interruptor dos Ajustes.
class CrashReportingAskCard extends ConsumerStatefulWidget {
  const CrashReportingAskCard({super.key});

  @override
  ConsumerState<CrashReportingAskCard> createState() => _CrashReportingAskCardState();
}

class _CrashReportingAskCardState extends ConsumerState<CrashReportingAskCard> {
  /// Se gravar a resposta falhou: o cartão sai até a próxima abertura em vez
  /// de ficar travado na tela, e o interruptor dos Ajustes continua lá.
  var _failed = false;

  Future<void> _answer({required bool granted}) async {
    final consent = ref.read(crashReportingConsentProvider.notifier);
    try {
      await (granted ? consent.grant() : consent.deny());
    } on Exception {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_failed || !ref.watch(askCrashReportingProvider)) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.only(top: BipaSpacing.s6),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(BipaRadius.lg),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, BipaSpacing.s1, BipaSpacing.s2, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.verified_user_outlined, size: 16, color: colors.inkMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l10n.crashAskEyebrow,
                      style: BipaText.caption.copyWith(fontWeight: FontWeight.w700, color: colors.inkMuted),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.crashAskDismiss,
                    onPressed: () => _answer(granted: false),
                    style: IconButton.styleFrom(foregroundColor: colors.ink, fixedSize: const Size.square(48)),
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
                ],
              ),
              Padding(
                // A margem do cartão é 20 dp; o × já ocupa 8 dp da direita.
                padding: const EdgeInsets.only(right: BipaSpacing.s3),
                child: Semantics(
                  header: true,
                  child: Text(
                    l10n.crashAskTitle,
                    style: BipaText.title.copyWith(fontWeight: FontWeight.w800, color: colors.ink),
                  ),
                ),
              ),
              const SizedBox(height: BipaSpacing.s3),
              Padding(
                padding: const EdgeInsets.only(right: BipaSpacing.s3),
                child: Text(
                  l10n.crashAskWhy,
                  style: BipaText.label.copyWith(fontWeight: FontWeight.w400, height: 20 / 14, color: colors.inkMuted),
                ),
              ),
              const SizedBox(height: BipaSpacing.s4),
              Padding(
                padding: const EdgeInsets.only(right: BipaSpacing.s3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _AnswerButton(label: l10n.crashAskSend, onPressed: () => _answer(granted: true)),
                    ),
                    const SizedBox(width: BipaSpacing.s2),
                    Expanded(
                      child: _AnswerButton(label: l10n.crashAskDecline, onPressed: () => _answer(granted: false)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// O botão de resposta: secundário, o mesmo para as duas respostas.
class _AnswerButton extends StatelessWidget {
  const _AnswerButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: BipaSpacing.s3),
      ),
      child: Text(label, textAlign: TextAlign.center),
    );
  }
}
