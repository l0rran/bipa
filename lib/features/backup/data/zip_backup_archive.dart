import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:bipa/core/backup/app_data_swap.dart';
import 'package:bipa/features/backup/domain/backup_exception.dart';
import 'package:bipa/features/backup/domain/backup_manifest.dart';
import 'package:bipa/features/backup/domain/backup_ports.dart';
import 'package:crypto/crypto.dart' as crypto;

/// O `.bipa` como zip (ADR 0023, seção 5), com o pacote `archive`.
///
/// O banco vai comprimido (o SQLite encolhe bem); as fotos, que já são JPEG,
/// vão sem compressão. O trabalho pesado (ler, calcular o SHA-256,
/// comprimir) roda num isolate, para a interface não travar com muitas
/// fotos. Cada arquivo passa pela memória um de cada vez: o banco de uma
/// casa tem poucos megabytes, e cada foto, algumas centenas de kilobytes.
final class ZipBackupArchive implements BackupArchive {
  const ZipBackupArchive();

  @override
  Future<BackupManifest> write({
    required String target,
    required BackupDraft draft,
    required String databasePath,
    required String photosPath,
    required Iterable<String> photoPaths,
  }) {
    final photos = photoPaths.toList()..sort();
    return Isolate.run(() => _write(target, draft, databasePath, photosPath, photos));
  }

  @override
  Future<BackupManifest> readManifest(String source) => Isolate.run(() => _withArchive(source, _manifestOf));

  @override
  Future<void> extract({
    required String source,
    required BackupManifest manifest,
    required String databasePath,
    required String photosPath,
  }) => Isolate.run(() => _withArchive(source, (archive) => _extract(archive, manifest, databasePath, photosPath)));

  static BackupManifest _write(
    String target,
    BackupDraft draft,
    String databasePath,
    String photosPath,
    List<String> photoPaths,
  ) {
    final encoder = ZipFileEncoder()..create(target, modified: draft.createdAt);
    try {
      final databaseBytes = File(databasePath).readAsBytesSync();
      final database = _entry(BackupManifest.databaseEntry, databaseBytes);
      encoder.addArchiveFile(ArchiveFile.bytes(BackupManifest.databaseEntry, databaseBytes));

      final photos = <BackupEntry>[];
      for (final path in photoPaths) {
        // Um `photo_path` estranho, ou de uma foto que não existe mais, fica
        // de fora: o produto volta sem foto, e a tela mostra o ícone.
        if (!BackupEntry.isSafePath(path)) continue;
        final file = File(_under(photosPath, path));
        if (!file.existsSync()) continue;
        final bytes = file.readAsBytesSync();
        photos.add(_entry(path, bytes));
        final name = '${BackupManifest.photosFolder}/$path';
        encoder.addArchiveFile(ArchiveFile.noCompress(name, bytes.length, bytes));
      }

      final manifest = BackupManifest.fromDraft(draft, database: database, photos: photos);
      encoder.addArchiveFile(ArchiveFile.string(BackupManifest.manifestEntry, jsonEncode(manifest.toJson())));
      return manifest;
    } finally {
      encoder.closeSync();
    }
  }

  static BackupManifest _manifestOf(Archive archive) {
    final bytes = archive.findFile(BackupManifest.manifestEntry)?.readBytes();
    if (bytes == null) throw const BackupException.notRecognized('sem manifesto');
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(bytes));
    } on FormatException {
      throw const BackupException.notRecognized('manifesto não é JSON');
    }
    return BackupManifest.fromJson(json);
  }

  static void _extract(Archive archive, BackupManifest manifest, String databasePath, String photosPath) {
    void place(String name, BackupEntry expected, String target) {
      final bytes = archive.findFile(name)?.readBytes();
      if (bytes == null) throw BackupException.damaged('falta $name');
      if (bytes.length != expected.size || _sha256(bytes) != expected.sha256) {
        throw BackupException.damaged('$name não confere');
      }
      File(target)
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes, flush: true);
    }

    place(BackupManifest.databaseEntry, manifest.database, databasePath);
    Directory(photosPath).createSync(recursive: true);
    for (final photo in manifest.photos) {
      place('${BackupManifest.photosFolder}/${photo.path}', photo, _under(photosPath, photo.path));
    }
  }

  /// Abre o zip em [source] e passa para [read]. O que não se lê como zip,
  /// ou como o conteúdo que o manifesto descreve, vira [BackupException].
  static T _withArchive<T>(String source, T Function(Archive archive) read) {
    final input = InputFileStream(source);
    try {
      final Archive archive;
      try {
        archive = ZipDecoder().decodeStream(input);
      } on Object catch (error) {
        // O decodificador do `archive` lança tipos variados (ArchiveException,
        // RangeError, FormatException) para um arquivo que não é zip ou foi
        // cortado: todos querem dizer o mesmo aqui.
        throw BackupException.notRecognized('não é zip: $error');
      }
      try {
        return read(archive);
      } on BackupException {
        rethrow;
      } on FileSystemException {
        rethrow;
      } on Object catch (error) {
        // Um conteúdo que não descomprime ou não é texto: o arquivo foi
        // danificado depois de gravado.
        throw BackupException.damaged('conteúdo ilegível: $error');
      }
    } finally {
      input.closeSync();
    }
  }

  static BackupEntry _entry(String path, Uint8List bytes) =>
      BackupEntry(path: path, sha256: _sha256(bytes), size: bytes.length);

  static String _sha256(List<int> bytes) => crypto.sha256.convert(bytes).toString();

  /// O caminho de [relative] (com `/`) dentro de [directory].
  static String _under(String directory, String relative) =>
      joinPath(directory, relative.split('/').join(Platform.pathSeparator));
}
