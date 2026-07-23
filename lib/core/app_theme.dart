import 'package:flutter/material.dart';

/// Central design system for Basketbrook Trails.
///
/// The visual language is intentionally minimal and warm: soft cream
/// surfaces, a single confident green as the primary action colour, a
/// golden accent for rewards and rounded, friendly typography.
class AppColors {
  AppColors._();

  static const Color cream = Color(0xFFFFF6E6);
  static const Color creamDeep = Color(0xFFF6E7C9);
  static const Color ink = Color(0xFF33291F);
  static const Color inkSoft = Color(0xFF6E5F4E);

  static const Color green = Color(0xFF5FB84F);
  static const Color greenDark = Color(0xFF3E9A3A);
  static const Color greenDeep = Color(0xFF2E7D33);

  static const Color gold = Color(0xFFFFC531);
  static const Color goldDark = Color(0xFFE8A21C);

  static const Color wood = Color(0xFF8A5A32);
  static const Color woodDark = Color(0xFF6B4423);

  static const Color sky = Color(0xFF8FD0F0);
  static const Color danger = Color(0xFFE86A5A);

  static const Color surface = Color(0xFFFFFFFF);
  static const Color shadow = Color(0x33000000);

  static const List<Color> greenGradient = [Color(0xFF6EC85B), Color(0xFF3E9A3A)];
  static const List<Color> goldGradient = [Color(0xFFFFD65A), Color(0xFFF2A828)];
  static const List<Color> creamGradient = [Color(0xFFFFF9EE), Color(0xFFF3E2C2)];
  static const List<Color> skyGradient = [Color(0xFFBDE9FF), Color(0xFF8FD0F0)];
}

class AppText {
  AppText._();

  static const String display = 'Fredoka';
  static const String body = 'Quicksand';

  static TextStyle title(double size,
          {Color color = AppColors.ink, FontWeight weight = FontWeight.w800}) =>
      TextStyle(
        fontFamily: display,
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: 1.05,
        letterSpacing: 0.2,
      );

  static TextStyle label(double size,
          {Color color = AppColors.ink, FontWeight weight = FontWeight.w700}) =>
      TextStyle(
        fontFamily: body,
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: 1.15,
      );
}

class AppTheme {
  static ThemeData build() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.cream,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.green,
        primary: AppColors.green,
        secondary: AppColors.gold,
        surface: AppColors.surface,
        brightness: Brightness.light,
      ),
      fontFamily: AppText.body,
      splashFactory: InkRipple.splashFactory,
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.ink,
        displayColor: AppColors.ink,
        fontFamily: AppText.body,
      ),
    );
  }
}
