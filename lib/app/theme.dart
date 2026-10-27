import 'package:flutter/material.dart';

/// Tema Material 3 do app, claro e escuro, a partir de uma cor semente.
abstract final class AppTheme {
  static const _seed = Color(0xFF0F8B5F);

  static ThemeData get light => _build(Brightness.light);

  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);
    return ThemeData(
      colorScheme: colorScheme,
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );
  }
}
