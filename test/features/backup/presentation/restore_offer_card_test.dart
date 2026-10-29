import 'package:bipa/core/database/database_provider.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/di/core_providers.dart';
import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/features/backup/domain/backup_exception.dart';
import 'package:bipa/features/backup/domain/backup_manifest.dart';
import 'package:bipa/features/backup/presentation/backup_files.dart';
import 'package:bipa/features/backup/presentation/backup_providers.dart';
import 'package:bipa/features/stock/presentation/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/backup_fakes.dart';
import '../../../helpers/fakes.dart';
import '../../../helpers/test_database.dart';

final _now = DateTime(2026, 10, 29, 9);
final _backupDay = DateTime(2026, 10, 12, 21);

/// O Início de um celular novo: o banco vazio e o backup do antigo à espera.
Future<FakeBackupController> _pumpHome(WidgetTester tester, FakeBackupController backup) async {
  tester.view
    ..physicalSize = const Size(411, 1400)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final db = createTestDatabase();
  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      clockProvider.overrideWithValue(() => _now),
      idGeneratorProvider.overrideWithValue(SequentialIdGenerator()),
      backupProvider.overrideWith(() => backup),
      backupFilesProvider.overrideWithValue(FakeBackupFiles()),
    ],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    container.dispose();
    await tester.runAsync(db.close);
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: BipaTheme.light,
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
        home: const Scaffold(body: HomePage()),
      ),
    ),
  );
  await _settle(tester);
  return backup;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump(const Duration(milliseconds: 100));
  }
  // A pasta das fotos não existe no teste, e o provider dela tenta de novo
  // depois de um tempo: o relógio passa por isso.
  await tester.pump(const Duration(seconds: 1));
}

final _offer = fakeBackupInfo(createdAt: _backupDay, madeHere: false);

/// Deixa o aviso sair, para o teste não terminar com o relógio dele rodando.
Future<void> _finishToasts(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 11));
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('o cartão fica no lugar do convite da casa vazia, com os números do arquivo', (tester) async {
    await _pumpHome(tester, FakeBackupController(initial: BackupState(restoreOffer: _offer)));

    expect(find.text('Backup do Google'), findsOneWidget);
    expect(find.text('Restaurar o backup de 12/10?'), findsOneWidget);
    expect(find.text('214'), findsOneWidget);
    expect(find.text('1.380'), findsOneWidget);
    expect(find.bySemanticsLabel('56 itens em casa'), findsOneWidget);
    expect(find.text('Restaurar'), findsOneWidget);
    expect(find.text('Começar do zero'), findsOneWidget);
    expect(find.byIcon(Icons.kitchen_outlined), findsNothing, reason: 'o convite da casa vazia sai');
  });

  testWidgets('sem oferta, o Início mostra o convite da casa vazia', (tester) async {
    await _pumpHome(tester, FakeBackupController());

    expect(find.text('Backup do Google'), findsNothing);
    expect(find.byIcon(Icons.kitchen_outlined), findsOneWidget);
  });

  testWidgets('"Restaurar" com a casa vazia restaura direto, sem folha e sem Desfazer', (tester) async {
    final backup = await _pumpHome(
      tester,
      FakeBackupController(
        initial: BackupState(restoreOffer: _offer),
        onPrepare: () async => fakePrepared(createdAt: _backupDay, current: BackupSummary.empty, currentIsEmpty: true),
      ),
    );

    await tester.tap(find.text('Restaurar'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(backup.calls, ['prepare', 'apply']);
    expect(find.text('Substituir pelo backup'), findsNothing);
    expect(find.text('Backup de 12/10 restaurado'), findsOneWidget);
    expect(find.text('Desfazer'), findsNothing);
    expect(find.text('Backup do Google'), findsNothing);
    await _finishToasts(tester);
  });

  testWidgets('os três números zerados, mas com lista ou mercado: passa pela folha, com Desfazer (BK4)', (
    tester,
  ) async {
    final backup = await _pumpHome(
      tester,
      FakeBackupController(
        initial: BackupState(restoreOffer: _offer),
        // Uma lista escrita à mão e um mercado não entram nos três números.
        onPrepare: () async => fakePrepared(createdAt: _backupDay, current: BackupSummary.empty),
      ),
    );

    await tester.tap(find.text('Restaurar'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(backup.calls, ['prepare'], reason: 'nada foi restaurado sem a confirmação');
    expect(find.text('Substituir pelo backup'), findsOneWidget);

    await tester.tap(find.text('Substituir pelo backup'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(backup.calls, ['prepare', 'apply']);
    expect(find.text('Desfazer'), findsOneWidget);
    await _finishToasts(tester);
  });

  testWidgets('"Restaurar" com algo já anotado passa pela folha de confirmação', (tester) async {
    final backup = await _pumpHome(tester, FakeBackupController(initial: BackupState(restoreOffer: _offer)));

    await tester.tap(find.text('Restaurar'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Substituir pelo backup'), findsOneWidget);
    expect(find.text('Neste celular agora: 230 produtos, 1.452 preços e 60 itens em casa.'), findsOneWidget);
    expect(backup.calls, ['prepare']);
  });

  testWidgets('arquivo que não abre: o cartão diz o problema e fica "Começar do zero"', (tester) async {
    await _pumpHome(
      tester,
      FakeBackupController(
        initial: BackupState(restoreOffer: _offer),
        onPrepare: () async => throw const BackupException.damaged(),
      ),
    );

    await tester.tap(find.text('Restaurar'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Não deu para abrir este backup'), findsOneWidget);
    expect(find.textContaining('Nada mudou neste celular'), findsOneWidget);
    expect(find.text('Restaurar'), findsNothing);
    expect(find.text('Começar do zero'), findsOneWidget);
  });

  testWidgets('"Começar do zero" tira o cartão, e o Desfazer o traz de volta', (tester) async {
    final backup = await _pumpHome(tester, FakeBackupController(initial: BackupState(restoreOffer: _offer)));

    await tester.tap(find.text('Começar do zero'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Backup do Google'), findsNothing);
    expect(find.text('Backup de 12/10 deixado de lado'), findsOneWidget);

    await tester.tap(find.text('Desfazer'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Backup do Google'), findsOneWidget);
    expect(backup.calls, isNot(contains('dismiss')), reason: 'o arquivo não foi adotado');
  });

  testWidgets('"Começar do zero" vale quando o aviso sai sozinho, depois de 10 s', (tester) async {
    final backup = await _pumpHome(tester, FakeBackupController(initial: BackupState(restoreOffer: _offer)));

    await tester.tap(find.text('Começar do zero'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 9));
    expect(backup.calls, isEmpty);

    await _finishToasts(tester);

    expect(backup.calls, ['dismiss']);
    expect(find.text('Backup do Google'), findsNothing);
  });
}
