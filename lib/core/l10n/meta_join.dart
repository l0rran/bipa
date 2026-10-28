import 'package:bipa/core/l10n/app_localizations.dart';

/// Linhas de apoio montadas por partes, com o separador vindo do ARB.
extension MetaJoin on AppLocalizations {
  /// "850 m · preços de 5 dias"; vazio sem partes.
  String joinMeta(Iterable<String> parts) => parts.isEmpty ? '' : parts.reduce(metaPair);
}

/// Enumerações de nomes, com a conjunção vinda do ARB.
extension NamesJoin on AppLocalizations {
  /// "Arroz", "Arroz e Feijão", "Arroz, Feijão e Leite"; com mais de [max]
  /// nomes, "Arroz, Feijão e mais 3".
  String joinNames(List<String> names, {int max = 3}) {
    assert(max >= 2, 'Com menos de dois nomes não há o que enumerar.');
    if (names.isEmpty) return '';
    if (names.length > max) {
      final shown = names.take(max - 1).reduce(namesPair);
      return namesMore(shown, names.length - (max - 1));
    }
    if (names.length == 1) return names.single;
    return namesLast(names.take(names.length - 1).reduce(namesPair), names.last);
  }
}
