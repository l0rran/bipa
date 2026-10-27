// GERADO por tool/generate_tokens.dart a partir de design/tokens.json.
// Não edite à mão: mude o tokens.json e rode `dart run tool/generate_tokens.dart`.
import 'package:flutter/animation.dart';

/// Espaçamentos, em pixels lógicos.
abstract final class BipaSpacing {
  /// Entre ícone e texto em chips.
  static const double s1 = 4.0;
  /// Entre chips e linhas de metadados.
  static const double s2 = 8.0;
  /// Padding interno de chips e campos.
  static const double s3 = 12.0;
  /// Margem lateral das telas e padding de cartões.
  static const double s4 = 16.0;
  /// Entre seções de uma tela.
  static const double s6 = 24.0;
  /// Respiro antes de ações principais.
  static const double s8 = 32.0;
}

/// Raios de canto. Elementos aninhados usam o raio externo menos o espaçamento.
abstract final class BipaRadius {
  /// Chips e etiquetas pequenas.
  static const double sm = 8.0;
  /// Campos de texto e cartões internos.
  static const double md = 14.0;
  /// Cartões, folhas inferiores e o ícone do app.
  static const double lg = 20.0;
  /// Botões, stepper de quantidade e barra de navegação.
  static const double pill = 999.0;
}

/// Espessuras de contorno.
abstract final class BipaStroke {
  static const double control = 1.5;
  static const double hairline = 1.0;
}

/// Durações e curvas de animação.
abstract final class BipaMotion {
  /// Resposta ao toque: escala do botão pressionado.
  static const Duration fast = Duration(milliseconds: 120);
  /// Troca de estado: cor, opacidade, número rolando, indicador da aba.
  static const Duration base = Duration(milliseconds: 220);
  /// Entrada de folhas, cartões e listas.
  static const Duration slow = Duration(milliseconds: 380);
  /// O 'Bipou!': check desenhado, contagem do preço.
  static const Duration celebrate = Duration(milliseconds: 600);
  /// Padrão para entradas e trocas de estado.
  static const Curve standard = Cubic(0.2, 0, 0, 1);
  /// Mola: toque, indicador da aba, números e o 'Bipou!'.
  static const Curve spring = Cubic(0.34, 1.56, 0.64, 1);
  /// Saídas: o que some acelera para fora.
  static const Curve exit = Cubic(0.3, 0, 1, 1);
}
