import 'package:bipa/core/accessibility/recommended_timeouts.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/features/backup/domain/backup_manifest.dart';
import 'package:bipa/features/backup/domain/backup_ports.dart';
import 'package:bipa/features/backup/presentation/backup_providers.dart';
import 'package:bipa/features/backup/presentation/restore_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/backup_fakes.dart';

/// Os arquivos do app com o que a restauração e o "Desfazer" usam: a reserva
/// existe depois de [replaceAppData], até [undoReplace] ou [discardReserve].
final class _FakeStorage implements BackupStorage {
  _FakeStorage({this.hasLatest = false});

  /// Há um `ultimo.bipa`, o do [_FakeArchive]; de outro celular enquanto
  /// [madeHereId] não é o id dele.
  final bool hasLatest;
  String? madeHereId;

  /// A marca de antes de uma restauração que adotou o `ultimo.bipa`.
  (String?,)? _markerBefore;

  var reserve = false;
  var undone = 0;
  var discarded = 0;

  @override
  Future<void> replaceAppData(RestoreWorkspace workspace, {String? adopt}) async {
    reserve = true;
    _markerBefore = adopt == null ? null : (madeHereId,);
    if (adopt != null) madeHereId = adopt;
  }

  @override
  Future<void> discard(String workspace) async {}

  @override
  Future<LatestBackupFile?> latest() async =>
      hasLatest ? LatestBackupFile(path: 'ultimo.bipa', size: 1, madeHereId: madeHereId) : null;

  @override
  Future<bool> undoReplace() async {
    if (!reserve) return false;
    reserve = false;
    undone++;
    final before = _markerBefore;
    if (before != null) madeHereId = before.$1;
    _markerBefore = null;
    return true;
  }

  @override
  Future<void> discardReserve() async {
    reserve = false;
    discarded++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _UnusedDatabase implements BackupDatabase {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// O `ultimo.bipa` é o backup `b1` de [_backupDay], o mesmo do
/// `fakePrepared`.
final class _FakeArchive implements BackupArchive {
  @override
  Future<BackupManifest> readManifest(String source) async => fakeManifest(createdAt: _backupDay);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _backupDay = DateTime(2026, 10, 12, 21);

/// Uma tela com um botão "restaurar" que faz o que a folha de confirmação
/// faz: troca os dados e mostra o aviso com o "Desfazer". O backup é o
/// `backupProvider` de verdade, sobre arquivos falsos. [screenReader] liga o
/// `accessibleNavigation`, como o TalkBack; [asked], o "Tempo para agir" do
/// Android.
Future<_FakeStorage> _pump(
  WidgetTester tester, {
  bool screenReader = false,
  RecommendedTimeouts asked = RecommendedTimeouts.none,
  bool pendingLatest = false,
  String restoredId = 'b1',
}) async {
  final storage = _FakeStorage(hasLatest: pendingLatest);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        backupStorageProvider.overrideWithValue(storage),
        backupDatabaseProvider.overrideWithValue(_UnusedDatabase()),
        backupArchiveProvider.overrideWithValue(_FakeArchive()),
      ],
      child: RecommendedTimeoutsScope(
        timeouts: asked,
        child: MaterialApp(
          theme: BipaTheme.light,
          locale: const Locale('pt', 'BR'),
          supportedLocales: const [Locale('pt', 'BR')],
          localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(accessibleNavigation: screenReader),
              child: ScaffoldMessenger(
                child: Builder(
                  builder: (context) => Scaffold(
                    body: Center(
                      child: Consumer(
                        builder: (context, ref, _) => TextButton(
                          onPressed: () => applyRestoreAndNotify(
                            backup: ref.read(backupProvider.notifier),
                            prepared: fakePrepared(createdAt: _backupDay, id: restoredId),
                            messenger: ScaffoldMessenger.of(context),
                            l10n: AppLocalizations.of(context),
                          ),
                          child: const Text('restaurar'),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return storage;
}

/// Restaura e espera o aviso terminar de entrar.
Future<void> _restore(WidgetTester tester) async {
  await tester.tap(find.text('restaurar'));
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

/// O "Desfazer" do aviso, tocado e levado até o fim.
Future<void> _undo(WidgetTester tester) async {
  await tester.tap(find.text('Desfazer'));
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  testWidgets('sem leitor de tela, o Desfazer vale nos 10 s do aviso', (tester) async {
    final storage = await _pump(tester);
    await _restore(tester);
    expect(storage.reserve, isTrue);

    await tester.pump(const Duration(seconds: 8));
    await _undo(tester);

    expect(storage.undone, 1);
    expect(find.text('O prazo para desfazer já passou.'), findsNothing);
    expect(storage.discarded, 0);
  });

  testWidgets('o aviso que sai sozinho descarta a reserva', (tester) async {
    final storage = await _pump(tester);
    await _restore(tester);

    await tester.pump(const Duration(seconds: 9));
    expect(storage.reserve, isTrue, reason: 'o aviso ainda está na tela');
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Desfazer'), findsNothing);
    expect(storage.reserve, isFalse);
    expect(storage.discarded, 1);
  });

  testWidgets('com TalkBack, o aviso espera e o Desfazer continua valendo além de 10 s (BK2)', (tester) async {
    final storage = await _pump(tester, screenReader: true);
    await _restore(tester);

    await tester.pump(const Duration(seconds: 15));
    await tester.pump(const Duration(minutes: 5));
    expect(find.text('Desfazer'), findsOneWidget);
    expect(storage.reserve, isTrue);
    expect(storage.discarded, 0);

    await _undo(tester);

    expect(storage.undone, 1);
    expect(find.text('O prazo para desfazer já passou.'), findsNothing);
  });

  testWidgets('com TalkBack, dispensar o aviso descarta a reserva', (tester) async {
    final storage = await _pump(tester, screenReader: true);
    await _restore(tester);
    await tester.pump(const Duration(seconds: 30));

    ScaffoldMessenger.of(tester.element(find.byType(Scaffold))).hideCurrentSnackBar();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(storage.reserve, isFalse);
    expect(storage.discarded, 1);
  });

  testWidgets('com o "Tempo para agir" em 1 minuto, o Desfazer vale aos 30 s', (tester) async {
    final storage = await _pump(tester, asked: const RecommendedTimeouts(controls: Duration(minutes: 1)));
    await _restore(tester);

    await tester.pump(const Duration(seconds: 30));
    expect(storage.reserve, isTrue);
    await _undo(tester);

    expect(storage.undone, 1);
    expect(find.text('O prazo para desfazer já passou.'), findsNothing);
  });

  testWidgets('com o dedo sobre o aviso, o tempo para e o Desfazer vale depois de 10 s', (tester) async {
    final storage = await _pump(tester);
    await _restore(tester);

    final finger = await tester.startGesture(tester.getCenter(find.text('Desfazer')));
    await tester.pump(const Duration(seconds: 20));
    expect(find.text('Desfazer'), findsOneWidget);
    expect(storage.reserve, isTrue);
    await finger.up();
    await tester.pump();
    await tester.pump();

    expect(storage.undone, 1);
    expect(find.text('O prazo para desfazer já passou.'), findsNothing);
  });

  testWidgets('outra restauração toma o lugar do aviso sem perder a reserva nova', (tester) async {
    final storage = await _pump(tester, screenReader: true);
    await _restore(tester);
    // O segundo aviso tira o primeiro, que sai sem o Desfazer.
    await _restore(tester);
    await tester.pump(const Duration(seconds: 1));

    expect(storage.reserve, isTrue, reason: 'a reserva é a da restauração nova');
    await _undo(tester);
    expect(storage.undone, 1);
  });

  group('com o backup de outro celular pendente (BK5)', () {
    Future<BackupState> state(WidgetTester tester) =>
        ProviderScope.containerOf(tester.element(find.byType(Scaffold))).read(backupProvider.future);

    testWidgets('restaurá-lo responde, e o Desfazer devolve a pergunta', (tester) async {
      await _pump(tester, pendingLatest: true);
      expect((await state(tester)).restoreOffer?.manifest.id, 'b1');

      await _restore(tester);
      final restored = await state(tester);
      expect((restored.pending, restored.restoreOffer), (false, null));

      await _undo(tester);
      final undone = await state(tester);
      expect(undone.pending, isTrue);
      expect(undone.restoreOffer?.manifest.id, 'b1', reason: 'o cartão do Início volta');
    });

    testWidgets('restaurar outro arquivo não responde por ele', (tester) async {
      await _pump(tester, pendingLatest: true, restoredId: 'copia');
      await state(tester);

      await _restore(tester);

      final restored = await state(tester);
      expect(restored.pending, isTrue);
      expect(restored.restoreOffer?.manifest.id, 'b1');
    });
  });
}
