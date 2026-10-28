import 'package:flutter/widgets.dart';

/// Alturas que acompanham o tamanho de letra do aparelho.
///
/// Listas horizontais precisam de altura fixa; calculada daqui, ela cresce
/// junto com a letra em vez de cortar o texto.
extension ScaledLineHeight on TextStyle {
  /// A altura de [lines] linhas deste estilo no tamanho de letra de [context].
  double scaledLineHeight(BuildContext context, {int lines = 1}) {
    final fontSize = this.fontSize ?? 14;
    return MediaQuery.textScalerOf(context).scale(fontSize) * (height ?? 1.2) * lines;
  }
}
