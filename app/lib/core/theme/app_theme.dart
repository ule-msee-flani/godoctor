import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../widgets/heartbeat_loader.dart';
import 'app_colors.dart';

/// Two distinct themes per the spec:
///  - [patientTheme]: mobile-first, blue-and-white telehealth brand, large
///    touch targets, minimal chrome (Uber/Duolingo-style simplicity).
///  - [professionalTheme]: denser, desktop/table-oriented, used for the
///    doctor and chemist dashboards (professional, desk-based use cases).
class AppTheme {
  AppTheme._();

  static TextTheme _baseTextTheme(Color ink, Color inkSoft) {
    // Start from Material's standard type scale so EVERY style has a font
    // size. Without it, styles we don't override (labelMedium, displaySmall...)
    // have no size, and `professionalTheme`'s `.apply(fontSizeFactor: ...)`
    // throws -- which crashed every doctor, chemist and admin screen.
    final base = Typography.material2021(
      platform: TargetPlatform.android,
    ).black.merge(Typography.englishLike2021);
    return GoogleFonts.interTextTheme(base).copyWith(
      displayLarge: GoogleFonts.inter(
        fontSize: 40,
        fontWeight: FontWeight.w700,
        color: ink,
        letterSpacing: -1.0,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: ink,
        letterSpacing: -0.6,
      ),
      headlineSmall: GoogleFonts.inter(
        fontSize: 21,
        fontWeight: FontWeight.w700,
        color: ink,
        letterSpacing: -0.4,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 19,
        fontWeight: FontWeight.w700,
        color: ink,
        letterSpacing: -0.3,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: ink,
        letterSpacing: -0.2,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 14.5,
        fontWeight: FontWeight.w600,
        color: ink,
        letterSpacing: -0.1,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: inkSoft,
        height: 1.4,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: inkSoft,
        height: 1.4,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12.5,
        fontWeight: FontWeight.w400,
        color: AppColors.inkFaint,
      ),
      labelLarge: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
    );
  }

  /// Quick fade-up between screens (see CalmPageTransitionsBuilder).
  static const _heartbeatTransitions = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: CalmPageTransitionsBuilder(),
      TargetPlatform.iOS: CalmPageTransitionsBuilder(),
      TargetPlatform.macOS: CalmPageTransitionsBuilder(),
      TargetPlatform.windows: CalmPageTransitionsBuilder(),
      TargetPlatform.linux: CalmPageTransitionsBuilder(),
      TargetPlatform.fuchsia: CalmPageTransitionsBuilder(),
    },
  );

  /// List rows: bold title, lighter secondary line, black icons.
  static ListTileThemeData _listTiles(TextTheme t) => ListTileThemeData(
    iconColor: AppColors.ink,
    titleTextStyle: t.titleSmall?.copyWith(
      fontWeight: FontWeight.w600,
      color: AppColors.ink,
    ),
    subtitleTextStyle: t.bodySmall?.copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      color: AppColors.inkSoft,
    ),
  );

  static ThemeData get patientTheme {
    const scheme = ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: AppColors.white,
      primaryContainer: AppColors.primarySoft,
      onPrimaryContainer: AppColors.primaryDark,
      secondary: AppColors.accentTeal,
      onSecondary: AppColors.white,
      secondaryContainer: AppColors.accentTealSoft,
      onSecondaryContainer: AppColors.accentTeal,
      surface: AppColors.white,
      onSurface: AppColors.ink,
      surfaceContainerHighest: AppColors.primarySoft,
      error: AppColors.danger,
      onError: AppColors.white,
      errorContainer: AppColors.dangerSoft,
      onErrorContainer: AppColors.danger,
      outline: AppColors.border,
      outlineVariant: AppColors.border,
    );

    final textTheme = _baseTextTheme(AppColors.ink, AppColors.inkSoft);

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.primarySofter,
      visualDensity: VisualDensity.comfortable,
      textTheme: textTheme,
      fontFamily: GoogleFonts.inter().fontFamily,
    );

    return base.copyWith(
      pageTransitionsTheme: _heartbeatTransitions,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.primarySofter,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: AppColors.ink),
        titleTextStyle: textTheme.titleLarge,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
          disabledBackgroundColor: AppColors.border,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: textTheme.labelLarge,
          elevation: 0,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: textTheme.labelLarge,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          foregroundColor: AppColors.primaryDark,
          side: const BorderSide(color: AppColors.border, width: 1.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: textTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        hintStyle: textTheme.bodyMedium?.copyWith(color: AppColors.inkFaint),
        labelStyle: textTheme.bodyMedium?.copyWith(color: AppColors.inkSoft),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border, width: 1.4),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border, width: 1.4),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.4),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.white,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.primarySoft,
        selectedColor: AppColors.primary,
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.primaryDark,
        ),
        secondaryLabelStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.white,
        ),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 32,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.primarySoft,
        circularTrackColor: AppColors.primarySoft,
      ),
      iconTheme: const IconThemeData(color: AppColors.ink, size: 22),
      listTileTheme: _listTiles(textTheme),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.ink,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.white,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        height: 68,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected)
                ? AppColors.ink
                : AppColors.inkFaint,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.bodySmall?.copyWith(
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? AppColors.ink
                : AppColors.inkFaint,
          ),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.inkSoft,
        indicatorColor: AppColors.primary,
        dividerColor: AppColors.border,
        labelStyle: textTheme.titleSmall,
        unselectedLabelStyle: textTheme.bodyMedium,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: AppColors.white,
          selectedBackgroundColor: AppColors.primary,
          selectedForegroundColor: AppColors.white,
          foregroundColor: AppColors.inkSoft,
          side: const BorderSide(color: AppColors.border),
        ),
      ),
    );
  }

  static ThemeData get professionalTheme {
    final textTheme = _baseTextTheme(
      AppColors.ink,
      AppColors.inkSoft,
    ).apply(fontSizeFactor: 0.95);
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: AppColors.white,
        primaryContainer: AppColors.primarySoft,
        secondary: AppColors.accentTeal,
        surface: AppColors.white,
        onSurface: AppColors.ink,
        surfaceContainerHighest: AppColors.primarySoft,
        error: AppColors.danger,
        outline: AppColors.border,
      ),
      visualDensity: VisualDensity.compact,
      textTheme: textTheme,
      fontFamily: GoogleFonts.inter().fontFamily,
    );
    return base.copyWith(
      pageTransitionsTheme: _heartbeatTransitions,
      iconTheme: const IconThemeData(color: AppColors.ink, size: 20),
      listTileTheme: _listTiles(textTheme),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 22,
            color: states.contains(WidgetState.selected)
                ? AppColors.ink
                : AppColors.inkFaint,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.bodySmall?.copyWith(
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? AppColors.ink
                : AppColors.inkFaint,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppColors.white,
        indicatorColor: Colors.transparent,
        selectedIconTheme: const IconThemeData(color: AppColors.ink),
        unselectedIconTheme: const IconThemeData(color: AppColors.inkFaint),
        selectedLabelTextStyle: textTheme.bodySmall?.copyWith(
          color: AppColors.ink,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: textTheme.bodySmall?.copyWith(
          color: AppColors.inkFaint,
        ),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStateProperty.all(AppColors.primarySoft),
        dataRowMinHeight: 40,
        dataRowMaxHeight: 48,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: const EdgeInsets.all(4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
    );
  }
}
