import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Onde ficam os dados da pessoa no aparelho: o banco e as fotos, na pasta
/// de documentos do app (`app_flutter/` no Android). O Auto Backup do
/// Android não leva nada daqui (ADR 0023, lacuna B1).
final class AppDataLocation {
  const AppDataLocation(this.documentsPath);

  final String documentsPath;

  /// O banco. É o mesmo arquivo que o `driftDatabase(name: 'bipa')` usaria
  /// por padrão.
  String get databasePath => joinPath(documentsPath, 'bipa.sqlite');

  /// As fotos dos produtos (ADR 0010); `products.photo_path` é relativo a ela.
  String get photosPath => joinPath(documentsPath, 'fotos');

  /// Onde a restauração prepara os arquivos novos e guarda os antigos durante
  /// a troca. Fica na mesma pasta do banco, para a troca ser só `rename`.
  String get restoreAreaPath => joinPath(documentsPath, 'restauracao');
}

/// A [AppDataLocation] do app.
Future<AppDataLocation> appDataLocation() async => AppDataLocation((await getApplicationDocumentsDirectory()).path);

/// Junta pedaços de caminho com o separador do sistema.
String joinPath(String first, String second, [String? third, String? fourth]) =>
    [first, second, ?third, ?fourth].join(Platform.pathSeparator);

/// Troca o banco e as fotos do app pelos de uma restauração (ADR 0023,
/// seção 5), sem deixar metade trocada.
///
/// Antes de mexer em qualquer arquivo, grava uma marca em
/// `restauracao/troca`; os arquivos antigos vão para `restauracao/reserva`, e
/// os novos tomam o lugar deles, tudo com `rename`. A marca só sai depois da
/// última troca. Se o app fechar no meio, a marca ainda está lá, e
/// [recover], chamado antes de abrir o banco, devolve os arquivos antigos.
///
/// Terminada a troca, a reserva fica, para o "Desfazer" da restauração
/// ([undo]), até [discardReserve]: quando o aviso da restauração sai sem o
/// "Desfazer", ou na primeira abertura do banco depois de o app fechar
/// ([AppDataSwap.atStartup]).
///
/// O banco precisa estar fechado durante a troca e o [undo].
final class AppDataSwap {
  AppDataSwap(this.location);

  final AppDataLocation location;

  /// Os arquivos que o SQLite cria ao lado do banco. Andam junto com ele.
  static const _sidecars = ['-journal', '-wal', '-shm'];

  File get _marker => File(joinPath(location.restoreAreaPath, 'troca'));
  String get _reservePath => joinPath(location.restoreAreaPath, 'reserva');
  String get _reserveDatabase => joinPath(_reservePath, 'bipa.sqlite');
  String get _reservePhotos => joinPath(_reservePath, 'fotos');

  /// Onde o [undo] põe a reserva enquanto ela volta para o lugar.
  String get _previousPath => joinPath(location.restoreAreaPath, 'anterior');

  /// Antes da primeira abertura do banco em cada execução do app: desfaz uma
  /// troca interrompida e apaga o que sobrou da área de restauração (a
  /// reserva de um "Desfazer" que não veio, uma restauração conferida e não
  /// aplicada).
  Future<void> atStartup() async {
    await recover();
    await _deleteDirectory(location.restoreAreaPath);
  }

  /// Põe o banco em [databasePath] e a pasta de fotos em [photosPath] no
  /// lugar dos atuais, que vão para a reserva. Os dois caminhos precisam
  /// estar no mesmo volume dos dados do app (a área de restauração serve).
  /// Se algo falhar, os arquivos antigos voltam antes de o erro subir.
  Future<void> replace({required String databasePath, required String photosPath}) =>
      _replace(databasePath: databasePath, photosPath: photosPath);

  /// "Desfazer": o banco e as fotos da reserva voltam para o lugar, e os de
  /// agora saem. Devolve `false` se não há reserva.
  Future<bool> undo() async {
    await recover();
    final reserve = Directory(_reservePath);
    if (!await reserve.exists()) return false;
    await _deleteDirectory(_previousPath);
    await reserve.rename(_previousPath);
    final database = joinPath(_previousPath, 'bipa.sqlite');
    // Sem banco na reserva, não havia banco antes da restauração (um app
    // recém-instalado): depois do desfazer, também não há.
    await _replace(
      databasePath: await File(database).exists() ? database : null,
      photosPath: joinPath(_previousPath, 'fotos'),
    );
    // A reserva agora tem os dados do backup, que a pessoa desfez.
    await discardReserve();
    return true;
  }

  /// Se há uma restauração para desfazer.
  Future<bool> hasReserve() => Directory(_reservePath).exists();

  /// Apaga a reserva: a última restauração não pode mais ser desfeita.
  Future<void> discardReserve() async {
    try {
      await _deleteDirectory(_reservePath);
      await _deleteDirectory(_previousPath);
    } on FileSystemException {
      // Sai na próxima abertura ([atStartup]).
    }
  }

  Future<void> _replace({required String? databasePath, required String photosPath}) async {
    // Uma troca anterior interrompida volta primeiro, para a reserva ser a
    // do estado de agora.
    await recover();
    final reserve = Directory(_reservePath);
    if (await reserve.exists()) await reserve.delete(recursive: true);
    await reserve.create(recursive: true);
    if (databasePath != null) {
      for (final suffix in _sidecars) {
        await _deleteFile('$databasePath$suffix');
      }
    }

    final hadDatabase = await File(location.databasePath).exists();
    final hadPhotos = await Directory(location.photosPath).exists();
    await _marker.writeAsString(jsonEncode({'hadDatabase': hadDatabase, 'hadPhotos': hadPhotos}), flush: true);
    try {
      if (hadDatabase) await _moveDatabase(location.databasePath, _reserveDatabase);
      if (hadPhotos) await Directory(location.photosPath).rename(_reservePhotos);
      if (databasePath != null) await _moveDatabase(databasePath, location.databasePath);
      final photos = Directory(photosPath);
      if (await photos.exists()) {
        await photos.rename(location.photosPath);
      } else {
        await Directory(location.photosPath).create(recursive: true);
      }
    } on Object {
      await recover();
      rethrow;
    }
    // A troca está feita: daqui em diante, só o [undo] volta atrás.
    await _marker.delete();
  }

  /// Desfaz uma troca interrompida, se houver; devolve se havia uma. Chame
  /// antes de abrir o banco.
  Future<bool> recover() async {
    if (!await _marker.exists()) return false;
    final state = await _readMarker();
    if (state != null) {
      final (:hadDatabase, :hadPhotos) = state;
      // Banco: se o atual já foi para a reserva (ou não havia), o que está no
      // lugar é o novo, ou nada; sai, e a reserva volta.
      if (await File(_reserveDatabase).exists() || !hadDatabase) {
        await _deleteDatabase(location.databasePath);
      }
      for (final suffix in ['', ..._sidecars]) {
        final reserved = File('$_reserveDatabase$suffix');
        if (await reserved.exists()) await reserved.rename('${location.databasePath}$suffix');
      }
      // Fotos: a mesma regra.
      final reservedPhotos = Directory(_reservePhotos);
      if (await reservedPhotos.exists() || !hadPhotos) await _deleteDirectory(location.photosPath);
      if (await reservedPhotos.exists()) await reservedPhotos.rename(location.photosPath);
    }
    // Sem estado legível, a marca foi gravada pela metade, antes de qualquer
    // arquivo mudar de lugar: não há o que desfazer.
    await _marker.delete();
    await _deleteDirectory(_reservePath);
    return true;
  }

  Future<({bool hadDatabase, bool hadPhotos})?> _readMarker() async {
    try {
      final json = jsonDecode(await _marker.readAsString());
      if (json case {'hadDatabase': final bool hadDatabase, 'hadPhotos': final bool hadPhotos}) {
        return (hadDatabase: hadDatabase, hadPhotos: hadPhotos);
      }
    } on FormatException {
      // Cai no `null` abaixo.
    }
    return null;
  }

  /// Os arquivos ao lado vão antes do banco: se a troca parar no meio, o
  /// banco que ficou no lugar ainda tem o que é dele, e [recover] devolve o
  /// que já tinha ido.
  static Future<void> _moveDatabase(String from, String to) async {
    for (final suffix in _sidecars) {
      final sidecar = File('$from$suffix');
      if (await sidecar.exists()) await sidecar.rename('$to$suffix');
    }
    await File(from).rename(to);
  }

  static Future<void> _deleteDatabase(String path) async {
    for (final suffix in ['', ..._sidecars]) {
      await _deleteFile('$path$suffix');
    }
  }

  static Future<void> _deleteFile(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  static Future<void> _deleteDirectory(String path) async {
    final directory = Directory(path);
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}
