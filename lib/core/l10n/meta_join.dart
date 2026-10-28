import 'package:bipa/core/l10n/app_localizations.dart';

/// Linhas de apoio montadas por partes, com o separador vindo do ARB.
extension MetaJoin on AppLocalizations {
  /// "850 m · preços de 5 dias"; vazio sem partes.
  String joinMeta(Iterable<String> parts) => parts.isEmpty ? '' : parts.reduce(metaPair);
}
