import 'package:flutter/material.dart';

/// Um valor que não pode quebrar a linha (preço, total, quantidade): com a
/// letra grande, encolhe até caber em [maxWidth] em vez de estourar a linha ou
/// empurrar o resto para fora da tela (H3). Cabendo, fica do tamanho do texto.
///
/// Quem usa mede a linha de cima (um `LayoutBuilder` acima do `Row`), porque
/// dentro de um filho do `Row` a largura que sobra não é conhecida.
class ShrinkToFit extends StatelessWidget {
  const ShrinkToFit({
    required this.maxWidth,
    required this.child,
    this.alignment = AlignmentDirectional.centerEnd,
    super.key,
  });

  final double maxWidth;
  final Widget child;

  /// Onde o texto fica quando encolhe: junto da borda de onde ele cresce.
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: FittedBox(fit: BoxFit.scaleDown, alignment: alignment, child: child),
    );
  }
}
