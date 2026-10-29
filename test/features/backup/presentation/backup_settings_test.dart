import 'dart:async';
import 'dart:io';

import 'package:bipa/core/crash_reporting/crash_reporting.dart';
import 'package:bipa/core/crash_reporting/crash_reporting_providers.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/di/core_providers.dart';
import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/features/backup/domain/backup_exception.dart';
import 'package:bipa/features/backup/domain/restore_backup.dart';
import 'package:bipa/features/backup/presentation/backup_files.dart';
import 'package:bipa/features/backup/presentation/backup_providers.dart';
import 'package:bipa/features/settings/presentation/settings_page.dart';
import 'package:bipa/features/settings/presentation/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/backup_fakes.dart';
import '../../../helpers/crash_reporting_fakes.dart';

final _now = DateTime(2026, 10, 29, 10);

/// Os Ajustes com o backup e o seletor falsos.
Future<void> pumpSettings(WidgetTester tester, {required FakeBackupController backup, BackupFiles? files}) async {
  tester.view
    ..physicalSize = const Size(411, 1600)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        backupProvider.overrideWith(() => backup),
        backupFilesProvider.overrideWithValue(files ?? FakeBackupFiles()),
        clockProvider.overrideWithValue(() => _now),
        crashReportingConsentStoreProvider.overrideWithValue(MemoryConsentStore()),
        crashReporterProvider.overrideWithValue(FakeCrashReporter()),
        initialCrashReportingConsentProvider.overrideWithValue(CrashReportingConsent.unasked),
        appVersionProvider.overrideWith((ref) async => '0.1.0'),
      ],
      child: MaterialApp(
        theme: BipaTheme.light,
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
        home: const SettingsPage(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

/// Deixa o aviso sair, para o teste não terminar com o relógio dele rodando.
Future<void> finishToasts(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 11));
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('o grupo "Backup" vem primeiro, com o último backup como número e as ações', (tester) async {
    await pumpSettings(
      tester,
      backup: FakeBackupController(
        initial: BackupState(lastBackup: fakeBackupInfo(createdAt: DateTime(2026, 10, 29, 8, 40))),
      ),
    );

    expect(find.text('BACKUP'), findsOneWidget);
    expect(tester.getTopLeft(find.text('BACKUP')).dy, lessThan(tester.getTopLeft(find.text('PRIVACIDADE')).dy));
    expect(find.text('Último backup'), findsOneWidget);
    expect(find.text('hoje'), findsOneWidget);
    expect(find.text('08:40'), findsOneWidget);
    expect(find.textContaining('Automático, uma vez por dia'), findsOneWidget);
    expect(find.text('Fazer backup agora'), findsOneWidget);
    expect(find.text('Salvar uma cópia…'), findsOneWidget);
    expect(find.text('Para guardar fora do celular'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp(r'^Último backup: hoje, 08:40\. Automático')),
      findsOneWidget,
      reason: 'o leitor de tela ouve o dia e a hora juntos',
    );
  });

  testWidgets('sem backup, "nenhum ainda"', (tester) async {
    await pumpSettings(tester, backup: FakeBackupController());
    expect(find.text('nenhum ainda'), findsOneWidget);
  });

  testWidgets('de ontem, "ontem"', (tester) async {
    await pumpSettings(
      tester,
      backup: FakeBackupController(
        initial: BackupState(lastBackup: fakeBackupInfo(createdAt: DateTime(2026, 10, 28, 8, 40))),
      ),
    );
    expect(find.text('ontem'), findsOneWidget);
  });

  testWidgets('mais velho, a data', (tester) async {
    await pumpSettings(
      tester,
      backup: FakeBackupController(
        initial: BackupState(lastBackup: fakeBackupInfo(createdAt: DateTime(2026, 10, 12, 21))),
      ),
    );
    expect(find.text('12/10'), findsOneWidget);
    expect(find.text('21:00'), findsOneWidget);
  });

  testWidgets('acima de 25 MB, a linha diz o tamanho e sugere "Salvar uma cópia…"', (tester) async {
    await pumpSettings(
      tester,
      backup: FakeBackupController(
        initial: BackupState(
          lastBackup: fakeBackupInfo(createdAt: DateTime(2026, 10, 29, 8, 40), size: 30 * 1024 * 1024 + 1),
        ),
      ),
    );

    expect(find.textContaining('Com 31 MB, passou dos 25 MB'), findsOneWidget);
    expect(find.textContaining('Automático, uma vez por dia'), findsNothing);
  });

  testWidgets('"Fazer backup agora" grava e o valor passa a "agora", sem aviso', (tester) async {
    final backup = FakeBackupController(
      initial: BackupState(lastBackup: fakeBackupInfo(createdAt: DateTime(2026, 10, 28, 8, 40))),
      onCreate: () async => fakeBackupInfo(createdAt: _now, id: 'novo'),
    );
    await pumpSettings(tester, backup: backup);

    await tester.tap(find.text('Fazer backup agora'));
    await tester.pump();
    await tester.pump();

    expect(backup.calls, ['create']);
    expect(find.text('agora'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('"Fazer backup agora" que falha avisa', (tester) async {
    final backup = FakeBackupController(onCreate: () async => throw const FileSystemExceptionForTest());
    await pumpSettings(tester, backup: backup);

    await tester.tap(find.text('Fazer backup agora'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Não deu para fazer o backup. Tente de novo.'), findsOneWidget);
    await finishToasts(tester);
  });

  testWidgets('"Salvar uma cópia…" grava e abre o "Salvar como" com o nome do dia', (tester) async {
    final backup = FakeBackupController();
    final files = FakeBackupFiles();
    await pumpSettings(tester, backup: backup, files: files);

    await tester.tap(find.text('Salvar uma cópia…'));
    await tester.pump();
    await tester.pump();

    expect(backup.calls, ['saveCopy']);
    expect(files.savedNames, ['bipa-2026-10-29.bipa']);
    expect(find.text('Cópia salva'), findsOneWidget);
    await finishToasts(tester);
  });

  testWidgets('voltar do "Salvar como" sem escolher não avisa nada', (tester) async {
    final files = FakeBackupFiles(saveAnswer: false);
    await pumpSettings(tester, backup: FakeBackupController(), files: files);

    await tester.tap(find.text('Salvar uma cópia…'));
    await tester.pump();
    await tester.pump();

    expect(files.savedNames, hasLength(1));
    expect(find.byType(SnackBar), findsNothing);
  });

  group('backup de outro celular sem resposta (BK1)', () {
    final pendingBackup = fakeBackupInfo(createdAt: DateTime(2026, 10, 12, 21), madeHere: false);
    BackupState pendingState() => BackupState(lastBackup: pendingBackup, restoreOffer: pendingBackup);

    testWidgets('a linha diz a origem e a data com o ano, e o automático está pausado', (tester) async {
      await pumpSettings(tester, backup: FakeBackupController(initial: pendingState()));

      expect(find.text('De outro celular. Toque para restaurar.'), findsOneWidget);
      expect(find.text('12/10'), findsOneWidget);
      expect(find.text('2026'), findsOneWidget);
      expect(find.text('21:00'), findsNothing);
      expect(find.textContaining('Automático, uma vez por dia'), findsNothing);
      expect(find.text('Automático pausado até você decidir'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Último backup: de outro celular, 12 de outubro de 2026. Restaurar'),
        findsOneWidget,
      );
    });

    testWidgets('tocar na linha abre a folha com esse arquivo, sem o seletor do Android', (tester) async {
      final backup = FakeBackupController(initial: pendingState());
      final files = FakeBackupFiles();
      await pumpSettings(tester, backup: backup, files: files);

      await tester.tap(find.text('De outro celular. Toque para restaurar.'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(files.picks, 0);
      expect(backup.calls, ['prepare']);
      expect(find.text('Restaurar o backup de 12/10/2026?'), findsOneWidget);
      expect(find.text('De outro celular'), findsOneWidget);
      expect(find.text('Substituir pelo backup'), findsOneWidget);

      await tester.tap(find.text('Substituir pelo backup'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Backup de 12/10/2026 restaurado'), findsOneWidget);
      await finishToasts(tester);
    });

    testWidgets('"Fazer backup agora" pergunta antes, e Cancelar não grava', (tester) async {
      final backup = FakeBackupController(initial: pendingState());
      await pumpSettings(tester, backup: backup);

      await tester.tap(find.text('Fazer backup agora'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Apagar o backup do outro celular?'), findsOneWidget);
      expect(
        find.text(
          'O backup de 12/10/2026, com 214 produtos, 1.380 preços e 56 itens em casa, dá lugar ao deste celular '
          'e não volta mais.',
          findRichText: true,
        ),
        findsOneWidget,
      );
      final confirm = tester.getRect(find.text('Apagar e fazer backup'));
      final cancel = tester.getRect(find.text('Cancelar'));
      expect(cancel.top, greaterThan(confirm.bottom), reason: 'os botões ficam empilhados');

      await tester.tap(find.text('Cancelar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Apagar o backup do outro celular?'), findsNothing);
      expect(backup.calls, isEmpty);
      expect(find.text('De outro celular. Toque para restaurar.'), findsOneWidget);
    });

    testWidgets('"Apagar e fazer backup" grava por cima, e o grupo volta ao de sempre', (tester) async {
      final backup = FakeBackupController(
        initial: pendingState(),
        onCreate: () async => fakeBackupInfo(createdAt: _now, id: 'novo'),
      );
      await pumpSettings(tester, backup: backup);

      await tester.tap(find.text('Fazer backup agora'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Apagar e fazer backup'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(backup.calls, ['createReplacing']);
      expect(find.text('agora'), findsOneWidget);
      expect(find.text('De outro celular. Toque para restaurar.'), findsNothing);
      expect(find.text('Automático pausado até você decidir'), findsNothing);
      expect(find.textContaining('Automático, uma vez por dia'), findsOneWidget);
    });

    testWidgets('deixado de lado hoje: a linha ainda restaura, e o automático volta amanhã (BK6)', (tester) async {
      final setAside = fakeBackupInfo(
        createdAt: DateTime(2026, 10, 12, 21),
        madeHere: false,
        setAsideAt: _now.subtract(const Duration(hours: 1)),
      );
      final backup = FakeBackupController(initial: BackupState(lastBackup: setAside));
      await pumpSettings(tester, backup: backup);

      expect(find.text('De outro celular. Toque para restaurar.'), findsOneWidget);
      expect(find.text('Automático volta amanhã'), findsOneWidget);
      expect(find.text('Automático pausado até você decidir'), findsNothing);

      await tester.tap(find.text('De outro celular. Toque para restaurar.'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(backup.calls, ['prepare']);
      expect(find.text('Restaurar o backup de 12/10/2026?'), findsOneWidget);
    });

    testWidgets('deixado de lado ontem: o automático já não está pausado (BK6)', (tester) async {
      final setAside = fakeBackupInfo(
        createdAt: DateTime(2026, 10, 12, 21),
        madeHere: false,
        setAsideAt: _now.subtract(const Duration(days: 1)),
      );
      await pumpSettings(
        tester,
        backup: FakeBackupController(initial: BackupState(lastBackup: setAside)),
      );

      expect(find.text('Automático volta amanhã'), findsNothing);
      expect(find.text('Automático pausado até você decidir'), findsNothing);
    });

    testWidgets('"Salvar uma cópia…" não pergunta', (tester) async {
      final backup = FakeBackupController(initial: pendingState());
      final files = FakeBackupFiles();
      await pumpSettings(tester, backup: backup, files: files);

      await tester.tap(find.text('Salvar uma cópia…'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Apagar o backup do outro celular?'), findsNothing);
      expect(backup.calls, ['saveCopy']);
      expect(find.text('Cópia salva'), findsOneWidget);
      await finishToasts(tester);
    });
  });

  group('restaurar de um arquivo', () {
    final backupDay = DateTime(2026, 10, 12, 21);
    PickedBackup picked() => PickedBackup(
      file: File('${Directory.systemTemp.path}/bipa-teste-nao-existe.bipa'),
      name: 'bipa-2026-10-12.bipa',
    );

    /// Abre o seletor (falso) e deixa a folha subir.
    Future<void> chooseFile(WidgetTester tester) async {
      await tester.tap(find.text('Restaurar de um arquivo…'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    testWidgets('confere, mostra os números e, confirmado, restaura com Desfazer', (tester) async {
      final preparing = Completer<PreparedRestore>();
      final applying = Completer<void>();
      final backup = FakeBackupController(onPrepare: () => preparing.future, onApply: (_) => applying.future);
      final files = FakeBackupFiles(picked: picked());
      await pumpSettings(tester, backup: backup, files: files);

      await chooseFile(tester);
      expect(find.text('Conferindo o arquivo'), findsOneWidget);
      expect(find.text('bipa-2026-10-12.bipa'), findsOneWidget);
      // Enquanto confere, o botão fica desabilitado com o mesmo rótulo.
      final checking = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Substituir pelo backup'));
      expect(checking.onPressed, isNull);

      preparing.complete(fakePrepared(createdAt: backupDay));
      await tester.pump();
      await tester.pump();
      expect(find.text('Restaurar o backup de 12/10/2026?'), findsOneWidget);
      expect(find.text('214'), findsOneWidget);
      expect(find.text('1.380'), findsOneWidget);
      expect(find.text('itens em casa'), findsOneWidget);
      expect(find.bySemanticsLabel('214 produtos'), findsOneWidget);
      expect(find.text('Neste celular agora: 230 produtos, 1.452 preços e 60 itens em casa.'), findsOneWidget);
      expect(find.textContaining('é trocado pelo que está no arquivo'), findsOneWidget);
      expect(find.textContaining('quantidade acertada'), findsNothing);

      await tester.tap(find.text('Substituir pelo backup'));
      await tester.pump();
      // Restaurando: o botão vira o indicador, a folha fica e o Cancelar sai.
      expect(find.bySemanticsLabel('Restaurando'), findsOneWidget);
      expect(find.text('Cancelar'), findsNothing);
      expect(find.text('Restaurar o backup de 12/10/2026?'), findsOneWidget);

      applying.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Restaurar o backup de 12/10/2026?'), findsNothing);
      expect(find.text('Backup de 12/10 restaurado'), findsOneWidget);
      expect(backup.calls, ['prepare', 'apply']);

      await tester.tap(find.text('Desfazer'));
      await tester.pump();
      await tester.pump();
      expect(backup.calls, ['prepare', 'apply', 'undo']);
      await finishToasts(tester);
    });

    testWidgets('o Desfazer fica 10 s no aviso', (tester) async {
      final backup = FakeBackupController();
      await pumpSettings(
        tester,
        backup: backup,
        files: FakeBackupFiles(picked: picked()),
      );

      await chooseFile(tester);
      await tester.pump();
      await tester.tap(find.text('Substituir pelo backup'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.pump(const Duration(seconds: 8));
      expect(find.text('Desfazer'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Desfazer'), findsNothing);
      expect(backup.calls, isNot(contains('undo')));
      expect(backup.discarded, 1, reason: 'o aviso saiu sem o Desfazer: a reserva sai');
    });

    testWidgets('desfazer não descarta a reserva', (tester) async {
      final backup = FakeBackupController();
      await pumpSettings(
        tester,
        backup: backup,
        files: FakeBackupFiles(picked: picked()),
      );

      await chooseFile(tester);
      await tester.pump();
      await tester.tap(find.text('Substituir pelo backup'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Desfazer'));
      await finishToasts(tester);

      expect(backup.calls, contains('undo'));
      expect(backup.discarded, 0);
    });

    testWidgets('avisa quantos itens tiveram a quantidade acertada pelos lotes', (tester) async {
      final backup = FakeBackupController(onPrepare: () async => fakePrepared(createdAt: backupDay, adjustedItems: 2));
      await pumpSettings(
        tester,
        backup: backup,
        files: FakeBackupFiles(picked: picked()),
      );

      await chooseFile(tester);
      await tester.pump();

      expect(find.text('2 itens tiveram a quantidade acertada pela soma das compras.'), findsOneWidget);
    });

    testWidgets('um backup mais velho que o último preço ou compra diz o que sai (BK3)', (tester) async {
      final backup = FakeBackupController(
        onPrepare: () async => fakePrepared(createdAt: DateTime(2025, 10, 12, 21), currentLatestActivity: _now),
      );
      await pumpSettings(
        tester,
        backup: backup,
        files: FakeBackupFiles(picked: picked()),
      );

      await chooseFile(tester);
      await tester.pump();

      expect(find.text('Restaurar o backup de 12/10/2025?'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Restaurar o backup de 12 de outubro de 2025?'),
        findsOneWidget,
        reason: 'o leitor de tela ouve a data por extenso',
      );
      expect(find.text('Os preços e as compras depois de 12/10/2025 saem deste celular.'), findsOneWidget);
    });

    testWidgets('um backup mais novo que tudo o que há aqui não tem a linha do que sai', (tester) async {
      final backup = FakeBackupController(
        onPrepare: () async => fakePrepared(createdAt: backupDay, currentLatestActivity: DateTime(2026, 10, 1)),
      );
      await pumpSettings(
        tester,
        backup: backup,
        files: FakeBackupFiles(picked: picked()),
      );

      await chooseFile(tester);
      await tester.pump();

      expect(find.textContaining('saem deste celular'), findsNothing);
    });

    testWidgets('Cancelar apaga a cópia conferida e não restaura', (tester) async {
      final backup = FakeBackupController();
      await pumpSettings(
        tester,
        backup: backup,
        files: FakeBackupFiles(picked: picked()),
      );

      await chooseFile(tester);
      await tester.pump();
      await tester.tap(find.text('Cancelar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Restaurar o backup de 12/10/2026?'), findsNothing);
      expect(backup.calls, ['prepare', 'cancel']);
    });

    testWidgets('voltar do seletor sem escolher não abre a folha', (tester) async {
      final backup = FakeBackupController();
      await pumpSettings(tester, backup: backup, files: FakeBackupFiles());

      await chooseFile(tester);

      expect(find.text('Conferindo o arquivo'), findsNothing);
      expect(backup.calls, isEmpty);
    });

    testWidgets('arquivo que não abre: a mensagem no lugar da confirmação, e escolher outro', (tester) async {
      final backup = FakeBackupController(onPrepare: () async => throw const BackupException.notRecognized());
      final files = FakeBackupFiles(picked: picked());
      await pumpSettings(tester, backup: backup, files: files);

      await chooseFile(tester);
      await tester.pump();

      expect(find.text('Não deu para abrir este backup'), findsOneWidget);
      expect(find.textContaining('Nada mudou neste celular'), findsOneWidget);
      expect(find.text('Substituir pelo backup'), findsNothing);
      expect(find.text('Fechar'), findsOneWidget);

      files.picked = null;
      await tester.tap(find.text('Escolher outro arquivo'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(files.picks, 2);
      expect(find.text('Não deu para abrir este backup'), findsNothing);
      expect(backup.calls, ['prepare']);
    });

    testWidgets('backup de um Bipa mais novo: "Atualizar o Bipa" abre a loja', (tester) async {
      final backup = FakeBackupController(onPrepare: () async => throw const BackupException.fromNewerApp());
      final files = FakeBackupFiles(picked: picked());
      await pumpSettings(tester, backup: backup, files: files);

      await chooseFile(tester);
      await tester.pump();

      expect(find.text('Este backup é de um Bipa mais novo'), findsOneWidget);
      expect(find.textContaining('Nada mudou neste celular'), findsOneWidget);
      await tester.tap(find.text('Atualizar o Bipa'));
      await tester.pump();
      expect(files.storeOpened, 1);

      await tester.tap(find.text('Fechar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Este backup é de um Bipa mais novo'), findsNothing);
    });

    testWidgets('se a troca falha, a folha fecha e o aviso diz que nada mudou', (tester) async {
      final backup = FakeBackupController(onApply: (_) async => throw const FileSystemExceptionForTest());
      await pumpSettings(
        tester,
        backup: backup,
        files: FakeBackupFiles(picked: picked()),
      );

      await chooseFile(tester);
      await tester.pump();
      await tester.tap(find.text('Substituir pelo backup'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Restaurar o backup de 12/10/2026?'), findsNothing);
      expect(find.text('Não deu para restaurar. Seus dados continuam como estavam.'), findsOneWidget);
      await finishToasts(tester);
    });
  });
}

/// Uma falha de disco ao gravar o backup.
final class FileSystemExceptionForTest implements Exception {
  const FileSystemExceptionForTest();
}
