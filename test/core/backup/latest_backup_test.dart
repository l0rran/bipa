import 'dart:io';

import 'package:bipa/core/backup/latest_backup.dart';
import 'package:flutter_test/flutter_test.dart';

/// O Auto Backup do Android leva só o backup `.bipa` mais recente (ADR 0023,
/// lacuna B1). Estes testes leem o manifesto e as regras do repositório e
/// conferem que elas apontam para o mesmo arquivo que o app grava. O domínio
/// `file` é a pasta `files/`; o banco e as fotos ficam em `app_flutter/` e,
/// sem `<include>` que os cite, não saem do aparelho.
void main() {
  const android = 'android/app/src/main';

  String read(String path) => File(path).readAsStringSync();

  /// Os `<include>` de um trecho das regras, como (domínio, caminho).
  List<(String, String)> includes(String xml) => [
    for (final match in RegExp(r'<include\s+domain="([^"]*)"\s+path="([^"]*)"\s*/>').allMatches(xml))
      (match.group(1)!, match.group(2)!),
  ];

  /// O conteúdo de `<tag>…</tag>` nas regras.
  String section(String xml, String tag) => RegExp('<$tag>(.*?)</$tag>', dotAll: true).firstMatch(xml)?.group(1) ?? '';

  test('o manifesto liga o Auto Backup com as regras dos dois formatos', () {
    final manifest = read('$android/AndroidManifest.xml');

    expect(manifest, contains('android:allowBackup="true"'));
    expect(manifest, contains('android:dataExtractionRules="@xml/data_extraction_rules"'));
    expect(manifest, contains('android:fullBackupContent="@xml/backup_rules"'));
  });

  test('no Android 12 em diante, a nuvem e a troca de aparelho levam só o último backup', () {
    final rules = read('$android/res/xml/data_extraction_rules.xml');

    for (final tag in ['cloud-backup', 'device-transfer']) {
      expect(includes(section(rules, tag)), [('file', latestBackupPath)], reason: tag);
    }
    expect(includes(rules), hasLength(2));
  });

  test('até o Android 11, o backup leva só o último backup', () {
    final rules = read('$android/res/xml/backup_rules.xml');

    expect(includes(rules), [('file', latestBackupPath)]);
  });

  test('o arquivo fica na pasta de suporte do app, no caminho das regras', () async {
    final support = Directory('${Directory.systemTemp.path}${Platform.pathSeparator}suporte');

    final file = await latestBackupFile(supportDirectory: () async => support);

    final separator = Platform.pathSeparator;
    expect(file.path, '${support.path}${separator}backup${separator}ultimo.bipa');
  });
}
