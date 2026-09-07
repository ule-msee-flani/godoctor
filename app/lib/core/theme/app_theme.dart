import 'package:flutter/material.dart';

/// Two distinct themes per the spec:
///  - [patientTheme]: mobile-first, large touch targets, minimal chrome
///    (Uber/Duolingo-style simplicity).
///  - [professionalTheme]: denser, desktop/table-oriented, used for the
///    doctor and chemist dashboards (professional, desk-based use cases).
class AppTheme {
  AppTheme._();

  static const _brandSeed = Color(0xFF0F9D6C); // calm clinical green

  static ThemeData get patientTheme {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: _brandSeed),
      visualDensity: VisualDensity.comfortable,
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(fontSizeFactor: 1.05),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: base.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.4,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.symmetric(vertical: 8),
      ),
    );
  }

  static ThemeData get professionalTheme {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _brandSeed,
        brightness: Brightness.light,
      ),
      visualDensity: VisualDensity.compact,
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(fontSizeFactor: 0.95),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStateProperty.all(
          base.colorScheme.surfaceContainerHighest,
        ),
        dataRowMinHeight: 40,
        dataRowMaxHeight: 48,
      ),
      cardTheme: const CardThemeData(
        elevation: 1,
        margin: EdgeInsets.all(4),
      ),
    );
  }
}
