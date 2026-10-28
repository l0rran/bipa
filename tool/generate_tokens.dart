// Gera lib/core/design_system/bipa_palette.dart e bipa_metrics.dart a partir
// de design/tokens.json, a fonte única dos tokens (ADR 0009).
//
// Uso: dart run tool/generate_tokens.dart
import 'dart:convert';
import 'dart:io';

void main() {
  final tokens = jsonDecode(File('design/tokens.json').readAsStringSync()) as Map<String, dynamic>;
  File('lib/core/design_system/bipa_palette.dart').writeAsStringSync(_palette(tokens));
  File('lib/core/design_system/bipa_metrics.dart').writeAsStringSync(_metrics(tokens));
  stdout.writeln('Tokens gerados a partir de design/tokens.json.');
}

const _header =
    '// GERADO por tool/generate_tokens.dart a partir de design/tokens.json.\n'
    '// Não edite à mão: mude o tokens.json e rode `dart run tool/generate_tokens.dart`.\n';

/// `surface-sunken` → `surfaceSunken`.
String _camel(String name) {
  final parts = name.split('-');
  return parts.first + parts.skip(1).map((p) => p[0].toUpperCase() + p.substring(1)).join();
}

/// `#F6C445` → `Color(0xFFF6C445)`; `rgba(255, 255, 255, 0.78)` → `Color(0xC7FFFFFF)`.
String _color(String value) {
  final hex = RegExp(r'^#([0-9A-Fa-f]{6})$').firstMatch(value);
  if (hex != null) return 'Color(0xFF${hex.group(1)!.toUpperCase()})';
  final rgba = RegExp(r'^rgba\((\d+),\s*(\d+),\s*(\d+),\s*([\d.]+)\)$').firstMatch(value);
  if (rgba == null) throw FormatException('Cor inválida em tokens.json: $value');
  final alpha = (double.parse(rgba.group(4)!) * 255).round();
  String byte(int v) => v.toRadixString(16).padLeft(2, '0').toUpperCase();
  final rgb = [1, 2, 3].map((i) => byte(int.parse(rgba.group(i)!))).join();
  return 'Color(0x${byte(alpha)}$rgb)';
}

String _palette(Map<String, dynamic> tokens) {
  final colors = ((tokens['color'] as Map<String, dynamic>)['tokens'] as List<dynamic>).cast<Map<String, dynamic>>();
  final names = [for (final token in colors) _camel(token['name'] as String)];
  final buffer = StringBuffer()
    ..write(_header)
    ..writeln("import 'package:flutter/material.dart';")
    ..writeln()
    ..writeln('/// Cores do Bipa com nomes de função (ADR 0009). Leia sempre pelo tema:')
    ..writeln('/// `context.colors.brand`. Os valores ficam só em [BipaPalette].')
    ..writeln('@immutable')
    ..writeln('final class BipaColors extends ThemeExtension<BipaColors> {')
    ..writeln('  const BipaColors({');
  for (final name in names) {
    buffer.writeln('    required this.$name,');
  }
  buffer
    ..writeln('  });')
    ..writeln();
  for (final token in colors) {
    buffer
      ..writeln('  /// ${token['usage']}')
      ..writeln('  final Color ${_camel(token['name'] as String)};')
      ..writeln();
  }
  buffer
    ..writeln('  @override')
    ..writeln('  BipaColors copyWith({');
  for (final name in names) {
    buffer.writeln('    Color? $name,');
  }
  buffer
    ..writeln('  }) {')
    ..writeln('    return BipaColors(');
  for (final name in names) {
    buffer.writeln('      $name: $name ?? this.$name,');
  }
  buffer
    ..writeln('    );')
    ..writeln('  }')
    ..writeln()
    ..writeln('  @override')
    ..writeln('  BipaColors lerp(BipaColors? other, double t) {')
    ..writeln('    if (other == null) return this;')
    ..writeln('    return BipaColors(');
  for (final name in names) {
    buffer.writeln('      $name: Color.lerp($name, other.$name, t)!,');
  }
  buffer
    ..writeln('    );')
    ..writeln('  }')
    ..writeln('}')
    ..writeln()
    ..writeln('/// Os valores da paleta, um por tema. É o único lugar do app com cores escritas.')
    ..writeln('abstract final class BipaPalette {');
  for (final theme in ['light', 'dark']) {
    buffer.writeln('  static const $theme = BipaColors(');
    for (final token in colors) {
      final value = (token['value'] as Map<String, dynamic>)[theme] as String;
      buffer.writeln('    ${_camel(token['name'] as String)}: ${_color(value)},');
    }
    buffer.writeln('  );');
    if (theme == 'light') buffer.writeln();
  }
  buffer.writeln('}');
  return buffer.toString();
}

String _metrics(Map<String, dynamic> tokens) {
  List<Map<String, dynamic>> group(String key) =>
      ((tokens[key] as Map<String, dynamic>)['tokens'] as List<dynamic>).cast<Map<String, dynamic>>();
  double px(String value) => double.parse(value.replaceAll('px', ''));
  final buffer = StringBuffer()
    ..write(_header)
    ..writeln("import 'package:flutter/animation.dart';")
    ..writeln()
    ..writeln('/// Espaçamentos, em pixels lógicos.')
    ..writeln('abstract final class BipaSpacing {');
  for (final token in group('spacing')) {
    final name = _camel((token['name'] as String).replaceFirst('space-', 's'));
    buffer
      ..writeln('  /// ${token['usage']}')
      ..writeln('  static const double $name = ${px(token['value'] as String)};');
  }
  buffer
    ..writeln('}')
    ..writeln()
    ..writeln('/// Raios de canto. Elementos aninhados usam o raio externo menos o espaçamento.')
    ..writeln('abstract final class BipaRadius {');
  for (final token in group('radius')) {
    final name = _camel((token['name'] as String).replaceFirst('radius-', ''));
    buffer
      ..writeln('  /// ${token['usage']}')
      ..writeln('  static const double $name = ${px(token['value'] as String)};');
  }
  buffer
    ..writeln('}')
    ..writeln()
    ..writeln('/// Espessuras de contorno.')
    ..writeln('abstract final class BipaStroke {');
  for (final token in group('stroke')) {
    final name = _camel((token['name'] as String).replaceFirst('stroke-', ''));
    buffer.writeln('  static const double $name = ${px(token['value'] as String)};');
  }
  buffer
    ..writeln('}')
    ..writeln()
    ..writeln('/// Durações e curvas de animação.')
    ..writeln('abstract final class BipaMotion {');
  for (final token in group('duration')) {
    final name = _camel((token['name'] as String).replaceFirst('duration-', ''));
    final ms = int.parse((token['value'] as String).replaceAll('ms', ''));
    buffer
      ..writeln('  /// ${token['usage']}')
      ..writeln('  static const Duration $name = Duration(milliseconds: $ms);');
  }
  for (final token in group('easing')) {
    final name = _camel((token['name'] as String).replaceFirst('easing-', ''));
    final numbers = RegExp(r'-?[\d.]+').allMatches(token['value'] as String).map((m) => m.group(0)).join(', ');
    buffer
      ..writeln('  /// ${token['usage']}')
      ..writeln('  static const Curve $name = Cubic($numbers);');
  }
  buffer.writeln('}');
  return buffer.toString();
}
