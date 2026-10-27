import 'dart:ui' show FontFeature;

import 'package:flutter/painting.dart';

/// Famílias de fonte embutidas no app (ver `assets/fonts/`). O app é offline,
/// então nada de baixar fontes em tempo de execução.
abstract final class BipaFonts {
  static const display = 'Manrope';
  static const body = 'Figtree';
  static const mono = 'JetBrainsMono';
}

/// Estilos de texto do design system, sem cor: a cor vem do tema ou do
/// componente. Os valores seguem os estilos de `design/tokens.json`.
abstract final class BipaText {
  static const _tabular = [FontFeature.tabularFigures()];

  /// O preço lido na etiqueta, no centro da captura.
  static const priceHero = TextStyle(
    fontFamily: BipaFonts.display,
    fontSize: 44,
    height: 48 / 44,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.88,
    fontFeatures: _tabular,
  );

  /// Título de tela.
  static const headline = TextStyle(
    fontFamily: BipaFonts.display,
    fontSize: 28,
    height: 34 / 28,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.28,
  );

  /// Títulos de seção e cabeçalho de folhas.
  static const title = TextStyle(
    fontFamily: BipaFonts.display,
    fontSize: 20,
    height: 26 / 20,
    fontWeight: FontWeight.w700,
  );

  /// Números de destaque: medidor, fatos e totais.
  static const number = TextStyle(
    fontFamily: BipaFonts.display,
    fontSize: 18,
    height: 20 / 18,
    fontWeight: FontWeight.w800,
    fontFeatures: _tabular,
  );

  /// Preço em listas e etiquetas.
  static const price = TextStyle(
    fontFamily: BipaFonts.display,
    fontSize: 20,
    height: 24 / 20,
    fontWeight: FontWeight.w800,
    fontFeatures: _tabular,
  );

  /// Nome do produto em listas.
  static const bodyLarge = TextStyle(
    fontFamily: BipaFonts.body,
    fontSize: 16,
    height: 22 / 16,
    fontWeight: FontWeight.w600,
  );

  /// Texto corrido e descrições.
  static const body = TextStyle(
    fontFamily: BipaFonts.body,
    fontSize: 15,
    height: 22 / 15,
    fontWeight: FontWeight.w400,
  );

  /// Botões, abas e chips.
  static const label = TextStyle(
    fontFamily: BipaFonts.body,
    fontSize: 14,
    height: 18 / 14,
    fontWeight: FontWeight.w700,
  );

  /// Metadados: mercado, data, origem do preço.
  static const caption = TextStyle(
    fontFamily: BipaFonts.body,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.24,
  );

  /// Códigos de barras (EAN) e números de conferência.
  static const barcode = TextStyle(
    fontFamily: BipaFonts.mono,
    fontSize: 13,
    height: 16 / 13,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.52,
  );
}
