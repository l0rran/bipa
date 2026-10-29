import 'dart:async';

import 'package:bipa/features/backup/domain/backup_exception.dart';
import 'package:bipa/features/backup/domain/backup_manifest.dart';
import 'package:meta/meta.dart';

/// O banco do app, do ponto de vista do backup (ADR 0023, seção 5).
abstract interface class BackupDatabase {
  /// O `schemaVersion` deste app.
  int get schemaVersion;

  /// Grava em [path] uma cópia consistente do banco aberto (`VACUUM INTO`).
  /// [path] não pode existir.
  Future<void> copyTo(String path);

  /// O que há na cópia em [path]: as linhas de cada tabela, o resumo e as
  /// fotos que os produtos citam.
  Future<BackupContents> describe(String path);

  /// Confere o banco de um backup em [path] e o leva ao esquema deste app,
  /// no próprio arquivo: o cabeçalho do SQLite, o `user_version` contra o
  /// [manifest], `PRAGMA integrity_check`, as contagens do manifesto, a
  /// migração, `PRAGMA foreign_key_check` e a leitura de cada linha pelo app
  /// (um valor de enum que ele não conhece vem de um app mais novo, ADR
  /// 0023, lacuna B4). Onde a soma dos lotes não é a quantidade do item em
  /// casa (ADR 0013), a quantidade passa a ser a soma, no próprio arquivo.
  /// Devolve o resumo do banco conferido e quantos itens foram acertados.
  /// Lança [BackupException].
  Future<CheckedBackup> check(String path, BackupManifest manifest);

  /// O resumo do banco do app agora ("Neste celular agora: …").
  Future<BackupSummary> currentSummary();

  /// Se o banco do app não tem nenhuma linha: o app acabou de ser instalado.
  Future<bool> isEmpty();

  /// O preço ou a compra mais recente do banco do app (a observação de
  /// preço, a ida ao mercado ou a entrada em casa), ou `null` sem nenhum. A
  /// confirmação compara com a data do backup para dizer o que sai (BK3).
  Future<DateTime?> latestActivity();
}

/// Um banco de backup conferido por [BackupDatabase.check].
@immutable
final class CheckedBackup {
  const CheckedBackup({required this.summary, this.adjustedItems = 0});

  /// Os números do banco conferido.
  final BackupSummary summary;

  /// Quantos itens em casa tinham a quantidade diferente da soma dos lotes e
  /// passaram a ter a soma (ADR 0023, seção 5): "2 itens tiveram a
  /// quantidade acertada".
  final int adjustedItems;
}

/// O que um banco guarda, para o manifesto.
@immutable
final class BackupContents {
  const BackupContents({required this.counts, required this.summary, required this.photoPaths});

  /// Linhas por tabela.
  final Map<String, int> counts;

  final BackupSummary summary;

  /// Os `products.photo_path`, relativos à pasta de fotos.
  final Set<String> photoPaths;

  /// Nenhuma linha em nenhuma tabela.
  bool get isEmpty => counts.values.every((count) => count == 0);
}

/// O arquivo `.bipa`.
abstract interface class BackupArchive {
  /// Grava em [target] o zip com o banco em [databasePath] e as fotos de
  /// [photoPaths] (relativas a [photosPath]; as que não existirem ficam de
  /// fora), mais o manifesto, e devolve o manifesto gravado.
  Future<BackupManifest> write({
    required String target,
    required BackupDraft draft,
    required String databasePath,
    required String photosPath,
    required Iterable<String> photoPaths,
  });

  /// Lê só o manifesto de [source]. Lança [BackupException] se o arquivo não
  /// é um `.bipa` ou é de um formato mais novo.
  Future<BackupManifest> readManifest(String source);

  /// Extrai o banco para [databasePath] e as fotos para [photosPath],
  /// conferindo o tamanho e o SHA-256 de cada um contra o [manifest]. Lança
  /// [BackupException] se algo faltar ou não conferir.
  Future<void> extract({
    required String source,
    required BackupManifest manifest,
    required String databasePath,
    required String photosPath,
  });
}

/// Os arquivos do app que o backup lê e a restauração troca.
abstract interface class BackupStorage {
  /// A pasta das fotos dos produtos.
  Future<String> photosPath();

  /// Uma pasta vazia para montar um backup, no mesmo volume do
  /// `ultimo.bipa`.
  Future<BackupWorkspace> createWorkspace();

  /// Uma pasta vazia para preparar uma restauração, no mesmo volume do banco
  /// e das fotos. Uma restauração preparada antes e não aplicada some.
  Future<RestoreWorkspace> restoreWorkspace();

  /// Apaga uma pasta de trabalho e o que houver nela.
  Future<void> discard(String workspace);

  /// Grava [bytes] num arquivo do app e devolve o caminho: para restaurar o
  /// que o seletor de arquivos do Android entrega como fluxo.
  Future<String> receive(Stream<List<int>> bytes);

  /// Escreve o arquivo em [path] em [destination] (o "Salvar como" do
  /// Android, por exemplo) e fecha o destino.
  Future<void> copyTo(String path, StreamConsumer<List<int>> destination);

  /// O `ultimo.bipa` (ADR 0023, seção 5), se houver.
  Future<LatestBackupFile?> latest();

  /// Põe o arquivo em [archivePath] no lugar do `ultimo.bipa` de uma vez
  /// (quem lê vê o antigo inteiro ou o novo inteiro) e lembra que o backup
  /// [backupId] foi feito neste aparelho. Devolve o arquivo publicado.
  Future<LatestBackupFile> publishLatest(String archivePath, String backupId);

  /// Lembra que o `ultimo.bipa` atual, de id [backupId], é deste aparelho:
  /// a pessoa já decidiu o que fazer com ele.
  Future<void> adoptLatest(String backupId);

  /// Fecha o banco do app, troca o banco e as fotos pelos de [workspace] e
  /// reabre. Os de antes ficam numa reserva, para [undoReplace]. Se a troca
  /// falha, os de antes voltam e o banco reabre com eles.
  Future<void> replaceAppData(RestoreWorkspace workspace);

  /// Volta o banco e as fotos da reserva, fechando e reabrindo o banco.
  /// Devolve `false` se não há reserva.
  Future<bool> undoReplace();

  /// Apaga a reserva: a restauração não pode mais ser desfeita.
  Future<void> discardReserve();
}

/// Onde um backup é montado.
@immutable
final class BackupWorkspace {
  const BackupWorkspace({required this.path, required this.databasePath, required this.archivePath});

  final String path;

  /// A cópia do banco.
  final String databasePath;

  /// O `.bipa` montado, antes de ir para o lugar do `ultimo.bipa`.
  final String archivePath;
}

/// Onde uma restauração é preparada.
@immutable
final class RestoreWorkspace {
  const RestoreWorkspace({required this.path, required this.databasePath, required this.photosPath});

  final String path;
  final String databasePath;
  final String photosPath;
}

/// O `ultimo.bipa` no aparelho.
@immutable
final class LatestBackupFile {
  const LatestBackupFile({required this.path, required this.size, required this.madeHereId});

  final String path;
  final int size;

  /// O id do último backup que este aparelho gravou ou adotou; quando é
  /// outro, o arquivo veio de outro aparelho (pelo Auto Backup do Android).
  final String? madeHereId;
}
