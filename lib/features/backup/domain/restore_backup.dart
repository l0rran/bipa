import 'package:bipa/features/backup/domain/backup_exception.dart';
import 'package:bipa/features/backup/domain/backup_manifest.dart';
import 'package:bipa/features/backup/domain/backup_ports.dart';
import 'package:bipa/features/backup/domain/read_latest_backup.dart';
import 'package:meta/meta.dart';

/// Um backup conferido e pronto para entrar no lugar dos dados do app: o
/// que a folha "Restaurar o backup de 12/10?" mostra antes de a pessoa
/// confirmar.
@immutable
final class PreparedRestore {
  const PreparedRestore({
    required this.manifest,
    required this.backup,
    required this.current,
    required this.currentIsEmpty,
    required this.workspace,
    this.adjustedItems = 0,
    this.currentLatestActivity,
  });

  final BackupManifest manifest;

  /// Os números do backup, contados no banco já conferido.
  final BackupSummary backup;

  /// Os números do aparelho agora ("Neste celular agora: …").
  final BackupSummary current;

  /// Se o banco do aparelho não tem nenhuma linha em nenhuma tabela
  /// ([BackupDatabase.isEmpty]): a restauração não apaga nada. Os três números
  /// de [current] zerados não bastam, porque a lista escrita à mão e os
  /// mercados criados ficam fora deles (BK4).
  final bool currentIsEmpty;

  /// Onde o banco e as fotos do backup esperam a confirmação.
  final RestoreWorkspace workspace;

  /// Quantos itens em casa tiveram a quantidade acertada pela soma dos
  /// lotes, para a folha avisar.
  final int adjustedItems;

  /// O preço ou a compra mais recente do aparelho agora
  /// ([BackupDatabase.latestActivity]), ou `null`.
  final DateTime? currentLatestActivity;

  /// O backup é mais velho que o último preço ou compra deste aparelho: o
  /// que veio depois da data dele sai com a restauração ("Os preços e as
  /// compras depois de 12/10/2025 saem deste celular.", BK3).
  bool get losesNewerData {
    final latest = currentLatestActivity;
    return latest != null && latest.isAfter(manifest.createdAt);
  }
}

/// Restaura um backup `.bipa` (ADR 0023, seção 5), em dois tempos, como na
/// folha do protótipo: [prepare] confere tudo numa cópia sem mudar nada no
/// aparelho, e [apply], depois da confirmação, troca os arquivos.
///
/// Restaurar substitui, não junta: depois, o banco e as fotos são os do
/// backup, e restaurar o mesmo arquivo de novo dá o mesmo resultado. Nada no
/// aparelho muda antes de tudo ser conferido:
/// 1. o manifesto: o formato e o esquema (mais novo que o do app é recusado:
///    a pessoa precisa atualizar o app; mais antigo é aceito, e a migração do
///    drift o traz até o atual);
/// 2. o banco e as fotos, extraídos numa pasta de trabalho, contra o tamanho
///    e o SHA-256 do manifesto;
/// 3. o banco extraído, pelo [BackupDatabase.check]: integridade, contagens,
///    migração, chaves estrangeiras e a leitura de cada linha. Um item cuja
///    quantidade não é a soma dos lotes não recusa o backup: a quantidade
///    passa a ser a soma, e a folha avisa ([PreparedRestore.adjustedItems]);
/// 4. só em [apply] o banco do app fecha, o banco e as fotos de agora vão
///    para uma reserva, os do backup entram no lugar e o banco reabre.
///
/// A reserva permite [undo] (o "Desfazer" do aviso) até [discardUndo] a
/// apagar, o que quem mostra o aviso faz quando ele sai sem o "Desfazer". O
/// prazo é o do aviso, não um relógio daqui: com leitor de tela, o aviso
/// espera a pessoa. Se o app fechar antes, a próxima abertura a apaga. O
/// `synced_at` fica como estava no backup.
final class RestoreBackup {
  const RestoreBackup({
    required BackupDatabase database,
    required BackupArchive archive,
    required BackupStorage storage,
  }) : _database = database,
       _archive = archive,
       _storage = storage;

  final BackupDatabase _database;
  final BackupArchive _archive;
  final BackupStorage _storage;

  /// Confere o backup em [source] (passos 1 a 3) e o deixa pronto. Lança
  /// [BackupException] se o arquivo não serve; nada no aparelho muda.
  Future<PreparedRestore> prepare(String source) async {
    final manifest = await _archive.readManifest(source);
    if (manifest.schemaVersion > _database.schemaVersion) {
      throw BackupException.fromNewerApp('esquema ${manifest.schemaVersion}');
    }

    final workspace = await _storage.restoreWorkspace();
    try {
      await _archive.extract(
        source: source,
        manifest: manifest,
        databasePath: workspace.databasePath,
        photosPath: workspace.photosPath,
      );
      final checked = await _database.check(workspace.databasePath, manifest);
      return PreparedRestore(
        manifest: manifest,
        backup: checked.summary,
        current: await _database.currentSummary(),
        currentIsEmpty: await _database.isEmpty(),
        workspace: workspace,
        adjustedItems: checked.adjustedItems,
        currentLatestActivity: await _database.latestActivity(),
      );
    } on Object {
      await _storage.discard(workspace.path);
      rethrow;
    }
  }

  /// [prepare] para um backup que chega como fluxo de bytes (o seletor de
  /// arquivos do Android entrega assim um arquivo do Drive, por exemplo).
  Future<PreparedRestore> prepareBytes(Stream<List<int>> bytes) async {
    final source = await _storage.receive(bytes);
    try {
      return await prepare(source);
    } finally {
      await _storage.discard(source);
    }
  }

  /// "Cancelar": apaga a cópia conferida. Nada no aparelho mudou.
  Future<void> cancel(PreparedRestore prepared) => _storage.discard(prepared.workspace.path);

  /// "Substituir pelo backup": troca o banco e as fotos do app pelos de
  /// [prepared] (passos 4 e 5). Se a troca falha, os de antes voltam e o
  /// erro sobe.
  ///
  /// Só quando o arquivo restaurado é o próprio `ultimo.bipa` que esperava
  /// resposta (o mesmo id), restaurar é a resposta: ele passa a ser deste
  /// aparelho, e o backup diário volta a substituí-lo. Restaurar outro
  /// arquivo não responde à pergunta sobre ele, que continua pendente (BK5).
  /// O "Desfazer" ([undo]) devolve a pendência como estava.
  Future<void> apply(PreparedRestore prepared) async {
    final latest = await ReadLatestBackup(storage: _storage, archive: _archive)();
    final answersPending = latest != null && !latest.madeHere && latest.manifest.id == prepared.manifest.id;
    try {
      await _storage.replaceAppData(prepared.workspace, adopt: answersPending ? prepared.manifest.id : null);
    } finally {
      await _storage.discard(prepared.workspace.path);
    }
  }

  /// Confere e aplica de uma vez, sem a confirmação no meio.
  Future<BackupManifest> call(String source) async {
    final prepared = await prepare(source);
    await apply(prepared);
    return prepared.manifest;
  }

  /// "Desfazer": volta o banco e as fotos de antes da última restauração e,
  /// se ela adotou o `ultimo.bipa`, a pendência dele: o cartão volta, e o
  /// diário segue pausado. Devolve `false` se a reserva já não existe.
  Future<bool> undo() => _storage.undoReplace();

  /// Fim do "Desfazer" (o aviso saiu sem ele): apaga a reserva.
  Future<void> discardUndo() => _storage.discardReserve();
}
