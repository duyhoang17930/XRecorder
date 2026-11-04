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
  static const primaryTitle = TextStyle(
    fontSize: 16,
    height: 22 / 16,
    fontWeight: FontWeight.w600,
    color: AppColors.primary,
  );
  static const body = TextStyle(fontSize: 13, height: 18 / 13);
  static const mutedBody = TextStyle(
    fontSize: 13,
    height: 18 / 13,
    color: AppColors.muted,
  );
  static const bodyEmphasis = TextStyle(
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w600,
  );
  static const bodyStrong = TextStyle(
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w700,
  );
  static const primaryBodyEmphasis = TextStyle(
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w700,
    color: AppColors.primary,
  );
  static const cyanBodyEmphasis = TextStyle(
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w800,
    color: AppColors.cyan,
  );
  static const bodySmall = TextStyle(fontSize: 12, height: 16 / 12);
  static const mutedBodySmall = TextStyle(
    fontSize: 12,
    height: 16 / 12,
    color: AppColors.muted,
  );
  static const caption = TextStyle(
    fontSize: 11,
    height: 14 / 11,
    fontWeight: FontWeight.w600,
  );
  static const mutedCaption = TextStyle(
    fontSize: 11,
    height: 14 / 11,
    fontWeight: FontWeight.w600,
    color: AppColors.muted,
  );
  static const primaryCaption = TextStyle(
    fontSize: 11,
    height: 14 / 11,
    fontWeight: FontWeight.w600,
    color: AppColors.primary,
  );
  static const micro = TextStyle(fontSize: 10, height: 13 / 10);
  static const mutedMicro = TextStyle(
    fontSize: 10,
    height: 13 / 10,
    color: AppColors.muted,
  );
  static const primaryMicro = TextStyle(
    fontSize: 10,
    height: 13 / 10,
    color: AppColors.primary,
  );
  static const cyanMicro = TextStyle(
    fontSize: 10,
    height: 13 / 10,
    color: AppColors.cyan,
  );
  static const metricLabel = TextStyle(
    fontSize: 9,
    height: 12 / 9,
    color: AppColors.muted,
  );
  static const metricAccent = TextStyle(
    fontSize: 9,
    height: 12 / 9,
    color: AppColors.cyan,
  );
  static const overline = TextStyle(
    fontSize: 10,
    height: 13 / 10,
    fontWeight: FontWeight.w700,
    letterSpacing: .8,
  );
  static const section = TextStyle(
    fontSize: 11,
    height: 14 / 11,
    fontWeight: FontWeight.w700,
    letterSpacing: .8,
  );
  static const button = TextStyle(fontSize: 14, fontWeight: FontWeight.w700);
  static const badge = TextStyle(fontSize: 10, fontWeight: FontWeight.w700);
  static const navigation = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w700,
  );
  static const appBarTitle = TextStyle(
    fontFamily: AppFonts.family,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.text,
  );
  static const metric = TextStyle(fontSize: 14, fontWeight: FontWeight.w600);
  static const timecode = TextStyle(
    fontFamily: AppFonts.monospace,
    fontSize: 12,
    height: 16 / 12,
  );
}

abstract final class AppTheme {
  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: AppFonts.family,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      onPrimary: AppColors.primaryForeground,
      secondary: AppColors.cyan,
      surface: AppColors.surface,
      onSurface: AppColors.text,
      error: AppColors.warning,
      onError: AppColors.text,
    ),
    textTheme: const TextTheme(
      displayLarge: AppTypography.display,
      headlineLarge: AppTypography.headline,
      titleLarge: AppTypography.headline,
      titleMedium: AppTypography.title,
      bodyLarge: AppTypography.bodyEmphasis,
      bodyMedium: AppTypography.body,
      bodySmall: AppTypography.caption,
      labelLarge: AppTypography.button,
      labelMedium: AppTypography.caption,
      labelSmall: AppTypography.micro,
    ),
    iconTheme: const IconThemeData(
      color: AppColors.text,
      size: AppIconSize.large,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.text,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: AppTypography.appBarTitle,
    ),
    dividerColor: AppColors.border,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
        textStyle: AppTypography.button,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: AppColors.text,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
        textStyle: AppTypography.bodyEmphasis,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: AppTypography.bodyEmphasis,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: AppColors.text,
        minimumSize: const Size(44, 44),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.card,
      selectedColor: AppColors.primary,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      labelStyle: AppTypography.bodySmall.copyWith(color: AppColors.text),
      secondaryLabelStyle: AppTypography.bodySmall.copyWith(
        color: AppColors.primaryForeground,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: AppColors.surface,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: AppTypography.body.copyWith(color: AppColors.muted),
      labelStyle: AppTypography.body.copyWith(color: AppColors.muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        borderSide: const BorderSide(color: AppColors.warning),
      ),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      textStyle: AppTypography.body,
      menuStyle: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(AppColors.elevated),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(AppRadius.control)),
            side: BorderSide(color: AppColors.border),
          ),
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: const BorderSide(color: AppColors.border),
      ),
      titleTextStyle: AppTypography.title.copyWith(color: AppColors.text),
      contentTextStyle: AppTypography.body.copyWith(color: AppColors.muted),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      modalBackgroundColor: AppColors.surface,
      modalBarrierColor: AppColors.scrim,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: AppColors.muted,
      dragHandleSize: Size(36, 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.card),
        ),
        side: BorderSide(color: AppColors.border),
      ),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: AppColors.cyan,
      thumbColor: AppColors.cyan,
      inactiveTrackColor: AppColors.overlay,
      overlayColor: AppColors.cyanOverlay,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.elevated,
      contentTextStyle: AppTypography.body.copyWith(color: AppColors.text),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.recordForeground,
      elevation: 0,
    ),
  );
}
