import 'package:bipa/core/design_system/bipa_metrics.dart';
import 'package:bipa/core/design_system/bipa_palette.dart';
import 'package:bipa/core/design_system/bipa_typography.dart';
import 'package:flutter/material.dart';

/// Monta o tema do Material 3 a partir da paleta do Bipa (ADR 0008 e 0009).
///
/// Componentes do Material continuam funcionando com a aparência do Bipa;
/// os componentes próprios leem as cores direto de [BipaColors].
abstract final class BipaTheme {
  static ThemeData get light => build(BipaPalette.light, Brightness.light);

  static ThemeData get dark => build(BipaPalette.dark, Brightness.dark);

  static ThemeData build(BipaColors colors, Brightness brightness) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: colors.brand,
      onPrimary: colors.onBrand,
      primaryContainer: colors.brandSoft,
      onPrimaryContainer: colors.ink,
      secondary: colors.ink,
      onSecondary: colors.surface,
      secondaryContainer: colors.surfaceSunken,
      onSecondaryContainer: colors.ink,
      tertiary: colors.place,
      onTertiary: colors.onPlace,
      error: colors.alertText,
      onError: colors.surface,
      errorContainer: colors.alertSoft,
      onErrorContainer: colors.alertText,
      surface: colors.surface,
      onSurface: colors.ink,
      onSurfaceVariant: colors.inkMuted,
      surfaceContainerLowest: colors.surface,
      surfaceContainerLow: colors.surface,
      surfaceContainer: colors.ground,
      surfaceContainerHigh: colors.surfaceSunken,
      surfaceContainerHighest: colors.surfaceSunken,
      outline: colors.line,
      outlineVariant: colors.line,
      scrim: colors.scrim,
      shadow: colors.ink,
      inverseSurface: colors.ink,
      onInverseSurface: colors.surface,
      inversePrimary: colors.brand,
    );

    const pill = StadiumBorder();
    final textTheme = TextTheme(
      headlineMedium: BipaText.headline,
      titleLarge: BipaText.title,
      titleMedium: BipaText.bodyLarge,
      bodyLarge: BipaText.body,
      bodyMedium: BipaText.body,
      labelLarge: BipaText.label,
      labelMedium: BipaText.caption,
      bodySmall: BipaText.caption,
    ).apply(bodyColor: colors.ink, displayColor: colors.ink);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: colors.ground,
      fontFamily: BipaFonts.body,
      textTheme: textTheme,
      extensions: [colors],
      splashFactory: InkSparkle.splashFactory,
      // O primary do esquema é o amarelo da marca, que some sobre o branco.
      // Ícones, seleção, cursor e rótulos em foco ficam em tinta; o amarelo
      // só aparece como fundo, com texto escuro (ADR 0009).
      iconTheme: IconThemeData(color: colors.ink),
      listTileTheme: ListTileThemeData(
        iconColor: colors.inkMuted,
        textColor: colors.ink,
        selectedColor: colors.ink,
        selectedTileColor: colors.brandSoft,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colors.ink,
        selectionColor: colors.brandSoft,
        selectionHandleColor: colors.ink,
      ),
      chipTheme: ChipThemeData(
        selectedColor: colors.brandSoft,
        checkmarkColor: colors.ink,
        labelStyle: BipaText.label.copyWith(color: colors.ink),
        side: BorderSide(color: colors.line),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.ground,
        foregroundColor: colors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: BipaText.title.copyWith(color: colors.ink),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.brand,
          foregroundColor: colors.onBrand,
          minimumSize: const Size(64, 52),
          shape: pill,
          textStyle: BipaText.label.copyWith(fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.ink,
          minimumSize: const Size(64, 52),
          shape: pill,
          side: BorderSide(color: colors.line, width: BipaStroke.control),
          textStyle: BipaText.label.copyWith(fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: colors.ink, textStyle: BipaText.label),
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BipaRadius.lg)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BipaRadius.md),
          borderSide: BorderSide.none,
        ),
        hintStyle: BipaText.body.copyWith(color: colors.inkMuted),
        floatingLabelStyle: BipaText.body.copyWith(color: colors.ink),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BipaRadius.md),
          borderSide: BorderSide(color: colors.ink, width: BipaStroke.control),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: colors.line,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colors.ink,
        contentTextStyle: BipaText.body.copyWith(color: colors.surface),
        actionTextColor: colors.brand,
        shape: const StadiumBorder(),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStatePropertyAll(colors.surface),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? colors.ink : colors.line,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      dividerTheme: DividerThemeData(color: colors.line, thickness: BipaStroke.hairline, space: 1),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: colors.ink, linearTrackColor: colors.surfaceSunken),
    );
  }
}

/// Atalhos para ler o design system a partir do contexto.
extension BipaThemeContext on BuildContext {
  /// As cores do Bipa do tema atual. Ex.: `context.colors.brand`.
  BipaColors get colors => Theme.of(this).extension<BipaColors>() ?? BipaPalette.light;
}
