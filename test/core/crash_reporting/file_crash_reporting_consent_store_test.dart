import 'dart:io';

import 'package:bipa/core/crash_reporting/crash_reporting.dart';
import 'package:bipa/core/crash_reporting/file_crash_reporting_consent_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;
  late FileCrashReportingConsentStore store;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('bipa_consent_');
    store = FileCrashReportingConsentStore(() async => directory);
  });

  tearDown(() => directory.delete(recursive: true));

  File file() => File('${directory.path}${Platform.pathSeparator}${FileCrashReportingConsentStore.fileName}');

  test('sem arquivo, a pessoa ainda não respondeu', () async {
    expect(await store.read(), CrashReportingConsent.unasked);
  });

  test('guarda e lê a resposta', () async {
    await store.write(CrashReportingConsent.granted);
    expect(await store.read(), CrashReportingConsent.granted);

    await store.write(CrashReportingConsent.denied);
    expect(await store.read(), CrashReportingConsent.denied);
  });

  test('a resposta sobrevive a outra instância (o app reaberto)', () async {
    await store.write(CrashReportingConsent.granted);
    final reopened = FileCrashReportingConsentStore(() async => directory);
    expect(await reopened.read(), CrashReportingConsent.granted);
  });

  test('conteúdo estranho conta como não respondido', () async {
    await file().writeAsString('talvez');
    expect(await store.read(), CrashReportingConsent.unasked);
  });

  test('cria a pasta se ela ainda não existir', () async {
    final nested = Directory('${directory.path}${Platform.pathSeparator}suporte');
    final nestedStore = FileCrashReportingConsentStore(() async => nested);
    await nestedStore.write(CrashReportingConsent.denied);
    expect(await nestedStore.read(), CrashReportingConsent.denied);
  });
}
