import 'package:flutter/material.dart';

import '../../core/constants/design_tokens.dart';

abstract final class AppTypography {
  static const display = TextStyle(
    fontSize: 26,
    height: 32 / 26,
    fontWeight: FontWeight.w800,
  );
  static const headline = TextStyle(
    fontSize: 20,
    height: 26 / 20,
    fontWeight: FontWeight.w700,
  );
  static const title = TextStyle(
    fontSize: 16,
    height: 22 / 16,
    fontWeight: FontWeight.w600,
  );
  static const body = TextStyle(fontSize: 13, height: 18 / 13);
  static const caption = TextStyle(
    fontSize: 11,
    height: 14 / 11,
    fontWeight: FontWeight.w600,
  );
  static const timecode = TextStyle(
    fontFamily: 'monospace',
    fontSize: 12,
    height: 16 / 12,
  );
}

abstract final class AppTheme {
  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: 'Manrope',
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      secondary: AppColors.cyan,
      surface: AppColors.surface,
      onPrimary: Color(0xFF391300),
      onSurface: AppColors.text,
      error: AppColors.warning,
    ),
    textTheme: const TextTheme(
      headlineLarge: AppTypography.display,
      titleLarge: AppTypography.headline,
      titleMedium: AppTypography.title,
      bodyMedium: AppTypography.body,
      bodySmall: AppTypography.caption,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        fontFamily: 'Manrope',
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
    dividerColor: AppColors.border,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
        textStyle: const TextStyle(
          fontFamily: 'Manrope',
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.card,
      selectedColor: AppColors.primary,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      labelStyle: const TextStyle(fontFamily: 'Manrope', fontSize: 12),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      showDragHandle: true,
    ),
  );
}
