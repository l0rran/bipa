import 'package:bipa/core/crash_reporting/crash_reporting.dart';
import 'package:bipa/core/crash_reporting/crash_reporting_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guarda a resposta em memória.
class _MemoryConsentStore implements CrashReportingConsentStore {
  _MemoryConsentStore([this.value = CrashReportingConsent.unasked]);

  CrashReportingConsent value;

  @override
  Future<CrashReportingConsent> read() async => value;

  @override
  Future<void> write(CrashReportingConsent consent) async => value = consent;
}

/// Anota o que foi pedido, sem rede.
class _FakeReporter implements CrashReporter {
  _FakeReporter({this.isAvailable = true});

  @override
  final bool isAvailable;

  final calls = <String>[];
  bool get running => calls.isNotEmpty && calls.last == 'start';

  @override
  Future<void> start() async => calls.add('start');

  @override
  Future<void> stop() async => calls.add('stop');
}

void main() {
  group('startCrashReportingIfGranted', () {
    test('liga o relatório quando a pessoa já aceitou', () async {
      final reporter = _FakeReporter();
      final consent = await startCrashReportingIfGranted(_MemoryConsentStore(CrashReportingConsent.granted), reporter);
      expect(consent, CrashReportingConsent.granted);
      expect(reporter.calls, ['start']);
    });

    test('não liga sem resposta nem com recusa', () async {
      for (final stored in [CrashReportingConsent.unasked, CrashReportingConsent.denied]) {
        final reporter = _FakeReporter();
        expect(await startCrashReportingIfGranted(_MemoryConsentStore(stored), reporter), stored);
        expect(reporter.calls, isEmpty);
      }
    });
  });

  group('SetCrashReportingConsent', () {
    test('aceitar grava a resposta e liga', () async {
      final store = _MemoryConsentStore();
      final reporter = _FakeReporter();
      await SetCrashReportingConsent(store, reporter)(granted: true);
      expect(store.value, CrashReportingConsent.granted);
      expect(reporter.calls, ['start']);
    });

    test('revogar desliga e grava a recusa', () async {
      final store = _MemoryConsentStore(CrashReportingConsent.granted);
      final reporter = _FakeReporter();
      await SetCrashReportingConsent(store, reporter)(granted: false);
      expect(store.value, CrashReportingConsent.denied);
      expect(reporter.calls, ['stop']);
    });
  });

  group('crashReportingConsentProvider', () {
    late _MemoryConsentStore store;
    late _FakeReporter reporter;

    ProviderContainer containerWith(CrashReportingConsent initial) {
      store = _MemoryConsentStore(initial);
      reporter = _FakeReporter();
      final container = ProviderContainer(
        overrides: [
          crashReportingConsentStoreProvider.overrideWithValue(store),
          crashReporterProvider.overrideWithValue(reporter),
          initialCrashReportingConsentProvider.overrideWithValue(initial),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('começa com a resposta lida na abertura', () {
      final container = containerWith(CrashReportingConsent.denied);
      expect(container.read(crashReportingConsentProvider), CrashReportingConsent.denied);
    });

    test('liga e desliga em tempo de execução', () async {
      final container = containerWith(CrashReportingConsent.unasked);
      final controller = container.read(crashReportingConsentProvider.notifier);

      await controller.grant();
      expect(container.read(crashReportingConsentProvider), CrashReportingConsent.granted);
      expect(store.value, CrashReportingConsent.granted);
      expect(reporter.running, isTrue);

      await controller.deny();
      expect(container.read(crashReportingConsentProvider), CrashReportingConsent.denied);
      expect(store.value, CrashReportingConsent.denied);
      expect(reporter.running, isFalse);
      expect(reporter.calls, ['start', 'stop']);
    });

    test('diz se o build pode mandar relatórios', () {
      final container = ProviderContainer(
        overrides: [crashReporterProvider.overrideWithValue(_FakeReporter(isAvailable: false))],
      );
      addTearDown(container.dispose);
      expect(container.read(crashReportingAvailableProvider), isFalse);
    });
  });
}
