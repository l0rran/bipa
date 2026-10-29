import 'package:bipa/features/backup/domain/backup_exception.dart';
import 'package:meta/meta.dart';

/// O `manifest.json` de um arquivo `.bipa` (ADR 0023, seção 5).
///
/// O `.bipa` é um zip com este manifesto, o banco em [databaseEntry] (uma
/// cópia feita com `VACUUM INTO`) e, em [photosFolder], as fotos que algum
/// `products.photo_path` cita, cada uma no caminho relativo que o banco
/// guarda.
@immutable
final class BackupManifest {
  const BackupManifest({
    required this.id,
    required this.createdAt,
    required this.appVersion,
    required this.schemaVersion,
    required this.counts,
    required this.summary,
    required this.database,
    required this.photos,
    this.format = currentFormat,
  });

  /// O manifesto de um backup recém-gravado: o que [draft] descreve, com o
  /// banco e as fotos que de fato entraram no arquivo.
  BackupManifest.fromDraft(BackupDraft draft, {required BackupEntry database, required List<BackupEntry> photos})
    : this(
        id: draft.id,
        createdAt: draft.createdAt,
        appVersion: draft.appVersion,
        schemaVersion: draft.schemaVersion,
        counts: draft.counts,
        summary: draft.summary,
        database: database,
        photos: photos,
      );

  /// A versão do formato que este app grava e lê. Um formato novo (outra
  /// organização do zip ou do manifesto) sobe este número; um app mais
  /// antigo recusa o arquivo e pede atualização.
  static const currentFormat = 1;

  static const manifestEntry = 'manifest.json';
  static const databaseEntry = 'bipa.sqlite';
  static const photosFolder = 'fotos';

  final int format;

  /// Identifica o backup: o app reconhece o `ultimo.bipa` que ele mesmo
  /// gravou (ADR 0023, seção 5).
  final String id;
  final DateTime createdAt;

  /// A versão do app que gravou (`0.1.0+1`), para diagnóstico.
  final String appVersion;

  /// O `schemaVersion` do banco no arquivo (o `user_version` do SQLite).
  final int schemaVersion;

  /// Quantas linhas cada tabela tinha.
  final Map<String, int> counts;

  /// Os números que a pessoa reconhece, para a tela mostrar sem abrir o
  /// banco (a oferta de restaurar no celular novo).
  final BackupSummary summary;

  /// O banco, com caminho [databaseEntry].
  final BackupEntry database;

  /// As fotos, com caminho relativo à pasta de fotos.
  final List<BackupEntry> photos;

  Map<String, Object?> toJson() => {
    'format': format,
    'id': id,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'appVersion': appVersion,
    'schemaVersion': schemaVersion,
    'counts': counts,
    'summary': summary.toJson(),
    'database': database.toJson(),
    'photos': [for (final photo in photos) photo.toJson()],
  };

  /// Lê um manifesto. Um formato mais novo que [currentFormat] pede app mais
  /// novo; qualquer campo que falte, tenha o tipo errado ou um caminho fora
  /// das pastas do backup recusa o arquivo.
  factory BackupManifest.fromJson(Object? json) {
    if (json is! Map<String, Object?>) throw const BackupException.notRecognized('manifesto não é um objeto');
    final format = json['format'];
    if (format is! int || format < 1) throw const BackupException.notRecognized('formato');
    if (format > currentFormat) throw BackupException.fromNewerApp('formato $format');
    if (json case {
      'id': final String id,
      'createdAt': final String createdAt,
      'appVersion': final String appVersion,
      'schemaVersion': final int schemaVersion,
      'counts': final Map<String, Object?> counts,
      'summary': final Object? summary,
      'database': final Object? database,
      'photos': final List<Object?> photos,
    } when id.isNotEmpty && schemaVersion >= 1) {
      final created = DateTime.tryParse(createdAt);
      if (created == null) throw const BackupException.notRecognized('data');
      final countsByTable = <String, int>{};
      for (final MapEntry(key: table, value: count) in counts.entries) {
        if (count is! int || count < 0 || !isTableName(table)) throw const BackupException.notRecognized('contagens');
        countsByTable[table] = count;
      }
      final databaseEntry = BackupEntry.fromJson(database);
      if (databaseEntry.path != BackupManifest.databaseEntry) throw const BackupException.notRecognized('banco');
      final photoEntries = [for (final photo in photos) BackupEntry.fromJson(photo)];
      if (photoEntries.map((photo) => photo.path).toSet().length != photoEntries.length) {
        throw const BackupException.notRecognized('foto repetida');
      }
      return BackupManifest(
        format: format,
        id: id,
        // Gravada em UTC; lida no fuso do aparelho, como as datas do banco.
        createdAt: created.toLocal(),
        appVersion: appVersion,
        schemaVersion: schemaVersion,
        counts: Map.unmodifiable(countsByTable),
        summary: BackupSummary.fromJson(summary),
        database: databaseEntry,
        photos: List.unmodifiable(photoEntries),
      );
    }
    throw const BackupException.notRecognized('campos do manifesto');
  }

  /// Um nome de tabela do SQLite como o drift gera (`price_observations`).
  /// O manifesto só aceita esses, porque a restauração os usa numa consulta.
  static bool isTableName(String name) => RegExp(r'^[a-z_][a-z0-9_]*$').hasMatch(name);
}

/// O que um backup novo vai dizer de si, antes de o arquivo ser gravado.
@immutable
final class BackupDraft {
  const BackupDraft({
    required this.id,
    required this.createdAt,
    required this.appVersion,
    required this.schemaVersion,
    required this.counts,
    required this.summary,
  });

  final String id;
  final DateTime createdAt;
  final String appVersion;
  final int schemaVersion;
  final Map<String, int> counts;
  final BackupSummary summary;
}

/// O que há num banco, nos números que a pessoa reconhece: os da folha
/// "Restaurar o backup de 12/10?" e da oferta no celular novo.
@immutable
final class BackupSummary {
  const BackupSummary({required this.products, required this.prices, required this.itemsAtHome});

  factory BackupSummary.fromJson(Object? json) {
    if (json case {
      'products': final int products,
      'prices': final int prices,
      'itemsAtHome': final int itemsAtHome,
    } when products >= 0 && prices >= 0 && itemsAtHome >= 0) {
      return BackupSummary(products: products, prices: prices, itemsAtHome: itemsAtHome);
    }
    throw const BackupException.notRecognized('resumo');
  }

  static const empty = BackupSummary(products: 0, prices: 0, itemsAtHome: 0);

  /// Produtos cadastrados.
  final int products;

  /// Preços anotados (observações).
  final int prices;

  /// Itens com alguma quantidade em casa.
  final int itemsAtHome;

  Map<String, Object?> toJson() => {'products': products, 'prices': prices, 'itemsAtHome': itemsAtHome};

  @override
  bool operator ==(Object other) =>
      other is BackupSummary &&
      other.products == products &&
      other.prices == prices &&
      other.itemsAtHome == itemsAtHome;

  @override
  int get hashCode => Object.hash(products, prices, itemsAtHome);

  @override
  String toString() => 'BackupSummary($products produtos, $prices preços, $itemsAtHome em casa)';
}

/// Um arquivo dentro do `.bipa`, com o SHA-256 e o tamanho, que a
/// restauração confere antes de usar.
@immutable
final class BackupEntry {
  const BackupEntry({required this.path, required this.sha256, required this.size});

  /// Lê uma entrada do manifesto; recusa caminho inseguro e hash malformado.
  factory BackupEntry.fromJson(Object? json) {
    if (json case {
      'path': final String path,
      'sha256': final String sha256,
      'size': final int size,
    } when isSafePath(path) && RegExp(r'^[0-9a-f]{64}$').hasMatch(sha256) && size >= 0) {
      return BackupEntry(path: path, sha256: sha256, size: size);
    }
    throw const BackupException.notRecognized('entrada do manifesto');
  }

  /// Caminho relativo, com `/`.
  final String path;

  /// SHA-256 do conteúdo, em hexadecimal minúsculo.
  final String sha256;
  final int size;

  Map<String, Object?> toJson() => {'path': path, 'sha256': sha256, 'size': size};

  /// Um caminho relativo que não sai da pasta onde é aberto: sem `..`, sem
  /// começar na raiz, sem `\` nem `:` (que no Windows mudam o sentido) e sem
  /// pedaço vazio.
  static bool isSafePath(String path) {
    if (path.isEmpty || path.contains(r'\') || path.contains(':')) return false;
    return path.split('/').every((segment) => segment.isNotEmpty && segment != '.' && segment != '..');
  }

  @override
  bool operator ==(Object other) =>
      other is BackupEntry && other.path == path && other.sha256 == sha256 && other.size == size;

  @override
  int get hashCode => Object.hash(path, sha256, size);

  @override
  String toString() => 'BackupEntry($path, $size bytes)';
}
