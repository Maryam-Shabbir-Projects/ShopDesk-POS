import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const seed = Color(0xFF0F6B5C);
  static const cursiveFont = 'Pacifico';

  /// Dark green on light screens; a lighter green on dark screens so it stays readable.
  static Color titleGreen(Brightness b) =>
      b == Brightness.light ? const Color(0xFF0B4A3A) : const Color(0xFF7FD6BC);

  static TextStyle cursiveTitle(Brightness b, {double size = 24}) => TextStyle(
        fontFamily: cursiveFont,
        fontSize: size,
        fontWeight: FontWeight.normal,
        color: titleGreen(b),
      );

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    final rounded = RoundedRectangleBorder(borderRadius: BorderRadius.circular(10));
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: scheme.surface,
        scrolledUnderElevation: 0,
        titleTextStyle: cursiveTitle(brightness),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size(48, 48), shape: rounded),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48), shape: rounded),
      ),
    );
  }
}
