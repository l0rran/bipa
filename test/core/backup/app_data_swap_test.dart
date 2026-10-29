import 'dart:convert';
import 'dart:io';

import 'package:bipa/core/backup/app_data_swap.dart';
import 'package:flutter_test/flutter_test.dart';

/// A troca dos arquivos na restauração (ADR 0023, seção 5): ou tudo muda, ou
/// nada muda, mesmo que o app feche no meio.
void main() {
  late Directory documents;
  late AppDataLocation location;
  late AppDataSwap swap;
  late Directory staged;

  setUp(() async {
    documents = await Directory.systemTemp.createTemp('bipa_swap');
    location = AppDataLocation(documents.path);
    swap = AppDataSwap(location);
    staged = await Directory(joinPath(location.restoreAreaPath, 'novo')).create(recursive: true);
  });

  tearDown(() => documents.delete(recursive: true));

  String read(String path) => File(path).readAsStringSync();
  void write(String path, String content) => File(path)
    ..createSync(recursive: true)
    ..writeAsStringSync(content);

  String photo(String name) => joinPath(location.photosPath, name);

  /// O app com um banco e uma foto, e uma restauração pronta com outros.
  void prepare() {
    write(location.databasePath, 'banco antigo');
    write(photo('a.jpg'), 'foto antiga');
    write(joinPath(staged.path, 'bipa.sqlite'), 'banco novo');
    write(joinPath(staged.path, 'fotos', 'b.jpg'), 'foto nova');
  }

  Future<void> replace() =>
      swap.replace(databasePath: joinPath(staged.path, 'bipa.sqlite'), photosPath: joinPath(staged.path, 'fotos'));

  test('troca o banco e as fotos, e não deixa reserva nem marca', () async {
    prepare();

    await replace();

    expect(read(location.databasePath), 'banco novo');
    expect(File(photo('a.jpg')).existsSync(), isFalse);
    expect(read(photo('b.jpg')), 'foto nova');
    expect(Directory(joinPath(location.restoreAreaPath, 'reserva')).existsSync(), isFalse);
    expect(File(joinPath(location.restoreAreaPath, 'troca')).existsSync(), isFalse);
    expect(await swap.recover(), isFalse);
  });

  test('um backup sem fotos deixa a pasta de fotos vazia', () async {
    write(location.databasePath, 'banco antigo');
    write(photo('a.jpg'), 'foto antiga');
    write(joinPath(staged.path, 'bipa.sqlite'), 'banco novo');

    await replace();

    expect(read(location.databasePath), 'banco novo');
    expect(Directory(location.photosPath).listSync(), isEmpty);
  });

  test('um arquivo do SQLite ao lado do banco antigo não fica junto do novo', () async {
    prepare();
    write('${location.databasePath}-journal', 'diário antigo');

    await replace();

    expect(File('${location.databasePath}-journal').existsSync(), isFalse);
  });

  test('se a troca falha no meio, os arquivos antigos voltam', () async {
    prepare();
    // O banco novo não existe: a troca falha depois de mover o antigo.
    File(joinPath(staged.path, 'bipa.sqlite')).deleteSync();

    await expectLater(replace(), throwsA(isA<FileSystemException>()));

    expect(read(location.databasePath), 'banco antigo');
    expect(read(photo('a.jpg')), 'foto antiga');
    expect(await swap.recover(), isFalse);
  });

  group('o app fechou no meio da troca', () {
    final reserve = joinPath('restauracao', 'reserva');

    void interrupted({required bool hadDatabase, required bool hadPhotos}) => write(
      joinPath(location.restoreAreaPath, 'troca'),
      jsonEncode({'hadDatabase': hadDatabase, 'hadPhotos': hadPhotos}),
    );

    test('depois de mover o banco antigo e pôr o novo: volta o antigo', () async {
      interrupted(hadDatabase: true, hadPhotos: true);
      write(joinPath(documents.path, reserve, 'bipa.sqlite'), 'banco antigo');
      write(location.databasePath, 'banco novo');
      // As fotos ainda não tinham saído.
      write(photo('a.jpg'), 'foto antiga');

      expect(await swap.recover(), isTrue);

      expect(read(location.databasePath), 'banco antigo');
      expect(read(photo('a.jpg')), 'foto antiga');
      expect(Directory(joinPath(documents.path, reserve)).existsSync(), isFalse);
    });

    test('depois de trocar as fotos também: voltam o banco e as fotos antigos', () async {
      interrupted(hadDatabase: true, hadPhotos: true);
      write(joinPath(documents.path, reserve, 'bipa.sqlite'), 'banco antigo');
      write(joinPath(documents.path, reserve, 'fotos', 'a.jpg'), 'foto antiga');
      write(location.databasePath, 'banco novo');
      write(photo('b.jpg'), 'foto nova');

      expect(await swap.recover(), isTrue);

      expect(read(location.databasePath), 'banco antigo');
      expect(read(photo('a.jpg')), 'foto antiga');
      expect(File(photo('b.jpg')).existsSync(), isFalse);
    });

    test('antes de mover qualquer coisa: nada muda', () async {
      interrupted(hadDatabase: true, hadPhotos: true);
      write(location.databasePath, 'banco antigo');
      write(photo('a.jpg'), 'foto antiga');

      expect(await swap.recover(), isTrue);

      expect(read(location.databasePath), 'banco antigo');
      expect(read(photo('a.jpg')), 'foto antiga');
    });

    test('num app sem dados ainda: o banco e as fotos novos saem', () async {
      interrupted(hadDatabase: false, hadPhotos: false);
      write(location.databasePath, 'banco novo');
      write(photo('b.jpg'), 'foto nova');

      expect(await swap.recover(), isTrue);

      expect(File(location.databasePath).existsSync(), isFalse);
      expect(Directory(location.photosPath).existsSync(), isFalse);
    });

    test('com a marca gravada pela metade: nada muda', () async {
      write(joinPath(location.restoreAreaPath, 'troca'), '{"hadDa');
      write(location.databasePath, 'banco antigo');

      expect(await swap.recover(), isTrue);

      expect(read(location.databasePath), 'banco antigo');
      expect(File(joinPath(location.restoreAreaPath, 'troca')).existsSync(), isFalse);
    });
  });
}
