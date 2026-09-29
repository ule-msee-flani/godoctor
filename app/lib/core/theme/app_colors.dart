import 'package:flutter/material.dart';

/// Semantic color tokens for the GoDoctor brand: a clean, trustworthy
/// blue-and-white telehealth palette. Use these directly for bespoke
/// compositions (gradients, illustration panels, status chips); for
/// standard widgets prefer `Theme.of(context).colorScheme`, which is built
/// from these same values in [AppTheme].
class AppColors {
  AppColors._();

  // Brand blue ramp
  static const primary = Color(0xFF1B63F2);
  static const primaryDark = Color(0xFF0D3E8F);
  static const primaryDarker = Color(0xFF082A63);
  static const primarySoft = Color(0xFFE8F0FE); // tinted fills, chips
  static const primarySofter = Color(0xFFF5F8FF); // page backgrounds

  // Secondary accent, used to differentiate the "order medicine" track
  // from the "see a doctor" track without leaving the blue family.
  static const accentTeal = Color(0xFF0EA5A8);
  static const accentTealSoft = Color(0xFFE3F7F7);

  // Ink / text
  static const ink = Color(0xFF0B1730);
  static const inkSoft = Color(0xFF57617A);
  static const inkFaint = Color(0xFF9AA8C3);

  // Structure
  static const border = Color(0xFFE3E9F5);
  static const borderStrong = Color(0xFFC8D5F0);
  static const white = Color(0xFFFFFFFF);

  // Status
  static const success = Color(0xFF17A673);
  static const successSoft = Color(0xFFE7F8F1);
  static const warning = Color(0xFFF2A93C);
  static const warningSoft = Color(0xFFFDF3E3);
  static const danger = Color(0xFFE0433D);
  static const dangerSoft = Color(0xFFFCEAE9);

  static const primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryDark],
  );

  static const heroGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [primaryDark, primary],
  );

  // Soft pastel card backgrounds (appointment, availability, readings...).
  static const mintGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEFFAF6), Color(0xFFD5F1EA)],
  );
  static const skyGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF0F5FF), Color(0xFFDCE7FF)],
  );
  static const lavenderGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF6F2FF), Color(0xFFE6DDFC)],
  );
  static const peachGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFF6EE), Color(0xFFFCE3D2)],
  );

  static const mint = Color(0xFF12A58A);
  static const lavender = Color(0xFF7B5CE6);
  static const peach = Color(0xFFE9804C);
}
