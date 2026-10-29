import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

/// Como as telas de backup escrevem datas, horas e números.
abstract final class BackupLabels {
  static final _dayMonth = DateFormat('dd/MM');
  static final _fullDate = DateFormat('dd/MM/yyyy');
  static final _year = DateFormat('yyyy');
  static final _time = DateFormat('HH:mm');
  static final _count = NumberFormat('#,##0', 'pt_BR');

  /// O dia de um backup deste celular no aviso: `12/10`.
  static String date(DateTime value) => _dayMonth.format(value);

  /// O dia com o ano, na confirmação e sempre que o backup é de outro
  /// celular (decisão do mantenedor em 29/10): `12/10/2025`. Um backup de um
  /// ano atrás não parece de duas semanas.
  static String fullDate(DateTime value) => _fullDate.format(value);

  /// O ano, embaixo do dia, na linha do backup de outro celular: `2026`.
  static String year(DateTime value) => _year.format(value);

  /// O dia por extenso, para o leitor de tela: "12 de outubro de 2025". Os
  /// nomes dos meses vêm dos dados do `intl` que as localizações do Material
  /// carregam.
  static String spokenDate(DateTime value) => DateFormat("d 'de' MMMM 'de' y", 'pt_BR').format(value);

  /// A hora do último backup: `08:40`.
  static String time(DateTime value) => _time.format(value);

  /// Um número dos fatos, com o ponto de milhar: `1.380`.
  static String count(int value) => _count.format(value);

  /// O dia do último backup em Ajustes: "hoje", "ontem" ou `12/10`.
  static String day(AppLocalizations l10n, DateTime value, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(value.year, value.month, value.day);
    if (day == today) return l10n.backupToday;
    if (day == DateTime(today.year, today.month, today.day - 1)) return l10n.backupYesterday;
    return date(value);
  }

  /// O tamanho em MB, arredondado para cima: um arquivo que passa dos 25 MB
  /// nunca aparece como "25 MB".
  static String megabytes(int bytes) => (bytes / (1024 * 1024)).ceil().toString();
}
