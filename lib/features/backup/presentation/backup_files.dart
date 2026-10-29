import 'dart:async';
import 'dart:io';

import 'package:bipa/core/backup/app_data_swap.dart' show joinPath;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import 'package:path_provider/path_provider.dart';

/// Um arquivo que a pessoa escolheu no seletor do Android, já copiado para
/// o app.
@immutable
final class PickedBackup {
  const PickedBackup({required this.file, required this.name});

  final File file;

  /// O nome que o seletor mostra ("bipa-2026-10-12.bipa").
  final String name;
}

/// O seletor de arquivos do Android para o backup (ADR 0023, seção 5): o
/// "Salvar como" de "Salvar uma cópia…", o "Abrir" de "Restaurar de um
/// arquivo…" e a loja de "Atualizar o Bipa". Nos testes, um falso.
abstract interface class BackupFiles {
  /// Grava o que [write] escrever onde a pessoa escolher, com o nome que
  /// [write] devolve. [write] roda antes do seletor abrir e fecha o destino.
  /// Devolve `false` se a pessoa voltou sem escolher.
  Future<bool> save(Future<String> Function(StreamConsumer<List<int>> destination) write);

  /// Abre o seletor e devolve o arquivo escolhido, ou `null` se a pessoa
  /// voltou sem escolher. Quem recebe apaga o arquivo depois de usar.
  Future<PickedBackup?> pick();

  /// A página do app na loja.
  Future<void> openStorePage();
}

/// O [BackupFiles] do Android, por um canal com o `MainActivity`
/// (`BackupFiles.kt`), sem plugin: o Storage Access Framework só precisa de
/// dois intents, e os bytes passam por arquivos do app, copiados no lado
/// nativo numa thread à parte.
final class AndroidBackupFiles implements BackupFiles {
  AndroidBackupFiles({MethodChannel? channel, Future<Directory> Function()? temporaryDirectory})
    : _channel = channel ?? const MethodChannel('dev.l0rran.bipa/backup_files'),
      _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;

  final MethodChannel _channel;
  final Future<Directory> Function() _temporaryDirectory;

  Future<Directory> _scratch() async {
    final directory = Directory(joinPath((await _temporaryDirectory()).path, 'backup_seletor'));
    await directory.create(recursive: true);
    return directory;
  }

  @override
  Future<bool> save(Future<String> Function(StreamConsumer<List<int>> destination) write) async {
    final file = File(joinPath((await _scratch()).path, 'copia.bipa'));
    try {
      final name = await write(file.openWrite());
      return await _channel.invokeMethod<bool>('saveAs', {'path': file.path, 'name': name}) ?? false;
    } finally {
      if (file.existsSync()) await file.delete();
    }
  }

  @override
  Future<PickedBackup?> pick() async {
    final file = File(joinPath((await _scratch()).path, 'escolhido.bipa'));
    final name = await _channel.invokeMethod<String>('open', {'target': file.path});
    if (name == null) {
      if (file.existsSync()) await file.delete();
      return null;
    }
    return PickedBackup(file: file, name: name);
  }

  @override
  Future<void> openStorePage() => _channel.invokeMethod<void>('openStore');
}

final backupFilesProvider = Provider<BackupFiles>((ref) => AndroidBackupFiles());
