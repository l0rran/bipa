import 'package:bipa/core/design_system/bipa_palette.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// Razão de contraste da WCAG 2.x entre duas cores opacas.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final (lighter, darker) = la > lb ? (la, lb) : (lb, la);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  // Todo texto do app passa 4,5:1 sobre o fundo em que aparece (ADR 0009).
  final textPairs = <String, (Color Function(BipaColors), Color Function(BipaColors))>{
    'ink / ground': ((c) => c.ink, (c) => c.ground),
    'ink / surface': ((c) => c.ink, (c) => c.surface),
    'ink / surfaceSunken': ((c) => c.ink, (c) => c.surfaceSunken),
    'inkMuted / ground': ((c) => c.inkMuted, (c) => c.ground),
    'inkMuted / surface': ((c) => c.inkMuted, (c) => c.surface),
    'inkMuted / surfaceSunken': ((c) => c.inkMuted, (c) => c.surfaceSunken),
    'onBrand / brand': ((c) => c.onBrand, (c) => c.brand),
    'brandText / surface': ((c) => c.brandText, (c) => c.surface),
    'brandText / brandSoft': ((c) => c.brandText, (c) => c.brandSoft),
    'onPrice / price': ((c) => c.onPrice, (c) => c.price),
    'onAlert / alert': ((c) => c.onAlert, (c) => c.alert),
    'alertText / surface': ((c) => c.alertText, (c) => c.surface),
    'alertText / alertSoft': ((c) => c.alertText, (c) => c.alertSoft),
    'onPlace / place': ((c) => c.onPlace, (c) => c.place),
    'positiveText / surface': ((c) => c.positiveText, (c) => c.surface),
    'positiveText / positiveSoft': ((c) => c.positiveText, (c) => c.positiveSoft),
    'onCamera / camera': ((c) => c.onCamera, (c) => c.camera),
  };

  for (final (theme, colors) in [('claro', BipaPalette.light), ('escuro', BipaPalette.dark)]) {
    group('Tema $theme', () {
      for (final MapEntry(key: name, value: (foreground, background)) in textPairs.entries) {
        test('$name passa 4,5:1', () {
          expect(contrast(foreground(colors), background(colors)), greaterThanOrEqualTo(4.5));
        });
      }

      // Gráficos (anel do medidor, ícones) pedem 3:1 (WCAG 1.4.11).
      test('alert como gráfico passa 3:1 sobre surface', () {
        expect(contrast(colors.alert, colors.surface), greaterThanOrEqualTo(3));
      });
    });
  }

  test('lerp entre os temas chega às cores do destino', () {
    final mixed = BipaPalette.light.lerp(BipaPalette.dark, 1);
    expect(mixed.ground, BipaPalette.dark.ground);
    expect(mixed.brand, BipaPalette.dark.brand);
  });
}
