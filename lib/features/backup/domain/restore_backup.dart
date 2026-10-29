import 'package:bipa/features/backup/domain/backup_exception.dart';
import 'package:bipa/features/backup/domain/backup_manifest.dart';
import 'package:bipa/features/backup/domain/backup_ports.dart';
import 'package:meta/meta.dart';

/// Um backup conferido e pronto para entrar no lugar dos dados do app: o
/// que a folha "Restaurar o backup de 12/10?" mostra antes de a pessoa
/// confirmar.
@immutable
final class PreparedRestore {
  const PreparedRestore({required this.manifest, required this.backup, required this.current, required this.workspace});

  final BackupManifest manifest;

  /// Os números do backup, contados no banco já conferido.
  final BackupSummary backup;

  /// Os números do aparelho agora ("Neste celular agora: …").
  final BackupSummary current;

  /// Onde o banco e as fotos do backup esperam a confirmação.
  final RestoreWorkspace workspace;
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
///    migração, chaves estrangeiras, soma dos lotes e a leitura de cada linha;
/// 4. só em [apply] o banco do app fecha, o banco e as fotos de agora vão
///    para uma reserva, os do backup entram no lugar e o banco reabre.
///
/// A reserva permite [undo] por [undoWindow] (o "Desfazer" do aviso); depois
/// dele, [discardUndo] a apaga. Se o app fechar antes, a próxima abertura a
/// apaga. O `synced_at` fica como estava no backup.
final class RestoreBackup {
  const RestoreBackup({
    required BackupDatabase database,
    required BackupArchive archive,
    required BackupStorage storage,
  }) : _database = database,
       _archive = archive,
       _storage = storage;

  /// Quanto tempo o "Desfazer" da restauração fica no aviso: o tempo longo
  /// de uma ação que mexe em muitos registros (protótipo
  /// RestaurarBackupResultado).
  static const undoWindow = Duration(seconds: 10);

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
      final backup = await _database.check(workspace.databasePath, manifest);
      return PreparedRestore(
        manifest: manifest,
        backup: backup,
        current: await _database.currentSummary(),
        workspace: workspace,
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
  Future<void> apply(PreparedRestore prepared) async {
    try {
      await _storage.replaceAppData(prepared.workspace);
    } finally {
      await _storage.discard(prepared.workspace.path);
    }

    // Os dados agora são os de um backup que a pessoa escolheu: o
    // `ultimo.bipa`, mesmo que tenha vindo de outro aparelho, deixa de
    // esperar resposta, e o backup diário volta a substituí-lo.
    final latest = await _storage.latest();
    if (latest != null) {
      try {
        await _storage.adoptLatest((await _archive.readManifest(latest.path)).id);
      } on BackupException {
        // Ilegível: o próximo backup o substitui de qualquer jeito.
      }
    }
  }

  /// Confere e aplica de uma vez, sem a confirmação no meio.
  Future<BackupManifest> call(String source) async {
    final prepared = await prepare(source);
    await apply(prepared);
    return prepared.manifest;
  }

  /// "Desfazer": volta o banco e as fotos de antes da última restauração.
  /// Devolve `false` se a reserva já não existe.
  Future<bool> undo() => _storage.undoReplace();

  /// Fim do prazo do "Desfazer": apaga a reserva.
  Future<void> discardUndo() => _storage.discardReserve();
}
