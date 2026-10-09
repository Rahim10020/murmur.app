import 'package:flutter/material.dart';

/// Palette Murmur — couleurs unies uniquement, aucun dégradé.
///
/// - [primary] : fond des actions principales seulement, jamais en texte.
/// - [ink] : texte en mode clair, fond de l'app en mode sombre,
///   fond des boutons secondaires en mode clair.
/// - [paper] : texte en mode sombre.
/// - [secondaryDark] : nuance adoucie pour le fond des boutons
///   secondaires en mode sombre.
class MurmurColors {
  const MurmurColors._();

  static const Color primary = Color(0xFFFFE01B);
  static const Color ink = Color(0xFF171717);
  static const Color paper = Color(0xFFFFFFFF);
  static const Color secondaryDark = Color(0xFF2E2E2E);
}

/// Thème applicatif : police Gotham, couleurs unies.
class MurmurTheme {
  const MurmurTheme._();

  static const String fontFamily = 'Gotham';

  static ThemeData light() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: MurmurColors.primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: MurmurColors.primary,
          onPrimary: MurmurColors.ink,
          surface: MurmurColors.paper,
          onSurface: MurmurColors.ink,
        );
    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      colorScheme: scheme,
      scaffoldBackgroundColor: MurmurColors.paper,
      appBarTheme: const AppBarTheme(
        backgroundColor: MurmurColors.paper,
        foregroundColor: MurmurColors.ink,
        elevation: 0,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: MurmurColors.primary,
        foregroundColor: MurmurColors.ink,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: MurmurColors.primary,
          foregroundColor: MurmurColors.ink,
        ),
      ),
    );
  }

  static ThemeData dark() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: MurmurColors.primary,
          brightness: Brightness.dark,
        ).copyWith(
          primary: MurmurColors.primary,
          onPrimary: MurmurColors.ink,
          surface: MurmurColors.ink,
          onSurface: MurmurColors.paper,
        );
    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      colorScheme: scheme,
      scaffoldBackgroundColor: MurmurColors.ink,
      appBarTheme: const AppBarTheme(
        backgroundColor: MurmurColors.ink,
        foregroundColor: MurmurColors.paper,
        elevation: 0,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: MurmurColors.primary,
        foregroundColor: MurmurColors.ink,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: MurmurColors.primary,
          foregroundColor: MurmurColors.ink,
        ),
      ),
    );
  }

  /// Style de bouton secondaire selon la luminosité.
  static ButtonStyle secondaryButtonStyle(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return FilledButton.styleFrom(
      backgroundColor: isDark ? MurmurColors.secondaryDark : MurmurColors.ink,
      foregroundColor: MurmurColors.paper,
    );
  }
}
