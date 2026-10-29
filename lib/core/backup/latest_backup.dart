import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Onde fica a cópia do backup `.bipa` mais recente (ADR 0023, lacuna B1),
/// relativo à pasta de suporte do app (`getApplicationSupportDirectory`, que
/// no Android é `files/`).
///
/// É o único arquivo que o Auto Backup do Android leva para a nuvem e para o
/// aparelho novo: as regras em `android/app/src/main/res/xml/` incluem só
/// este caminho, então o banco e as fotos, que ficam na pasta de documentos
/// (`app_flutter/`), ficam de fora. Mudar o caminho aqui exige mudar as
/// regras também; o teste `latest_backup_test.dart` confere os dois.
///
/// O nome é fixo: cada backup novo substitui o anterior.
const latestBackupPath = 'backup/ultimo.bipa';

/// O arquivo do backup mais recente. [supportDirectory] existe para os
/// testes.
Future<File> latestBackupFile({Future<Directory> Function() supportDirectory = getApplicationSupportDirectory}) async {
  final directory = await supportDirectory();
  final relative = latestBackupPath.replaceAll('/', Platform.pathSeparator);
  return File('${directory.path}${Platform.pathSeparator}$relative');
}
