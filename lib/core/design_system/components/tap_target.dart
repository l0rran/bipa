import 'package:flutter/widgets.dart';

/// Deixa a área de toque de um controle pequeno com pelo menos 48×48 dp sem
/// mudar o desenho, como o `MaterialTapTargetSize.padded` dos botões do
/// Material. O toque na folga em volta vale como toque no controle.
///
/// O controle de dentro continua com o próprio toque (e o efeito de toque);
/// a folga só repete o [onTap]. Não entra na árvore de acessibilidade: o
/// rótulo e a ação ficam com quem envolve o controle.
class TapTarget extends StatelessWidget {
  const TapTarget({required this.onTap, required this.child, super.key});

  /// O lado mínimo recomendado pelo Material e pelas diretrizes do Android.
  static const minSize = 48.0;

  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: minSize, minHeight: minSize),
        // Fatores 1: do tamanho do controle, mas nunca menor que o mínimo.
        child: Center(widthFactor: 1, heightFactor: 1, child: child),
      ),
    );
  }
}
