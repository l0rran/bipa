import 'package:bipa/core/crash_reporting/crash_reporting.dart';
import 'package:bipa/core/crash_reporting/crash_reporting_providers.dart';
import 'package:bipa/features/shopping_list/presentation/shopping_list_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// A versão do app (`0.1.0`), sem o número da compilação.
final appVersionProvider = FutureProvider<String>((ref) async => (await PackageInfo.fromPlatform()).version);

/// Se o Início deve perguntar sobre o relatório de falhas (ADR 0025): só em
/// build com DSN, só enquanto a pessoa não respondeu e só na abertura do app
/// seguinte à primeira compra terminada: ela já sabe o que o app faz, e o fim
/// da compra não disputa a tela com o aviso de desfazer.
final askCrashReportingProvider = Provider.autoDispose<bool>((ref) {
  if (!ref.watch(crashReportingAvailableProvider)) return false;
  if (ref.watch(crashReportingConsentProvider) != CrashReportingConsent.unasked) return false;
  return ref.watch(finishedTripBeforeSessionProvider).value ?? false;
});
