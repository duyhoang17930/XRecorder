import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/design_tokens.dart';
import '../../core/constants/app_icons.dart';

/// Offline Manrope remains the single UI family after the TASK 02 comparison.
abstract final class AppTypography {
  static const display = TextStyle(
    fontSize: 28,
    height: 1.2,
    fontWeight: FontWeight.w800,
    letterSpacing: -.7,
  );
  static const headline = TextStyle(
    fontSize: 20,
    height: 1.3,
    fontWeight: FontWeight.w700,
    letterSpacing: -.3,
  );
  static const title = TextStyle(
    fontSize: 16,
    height: 1.4,
    fontWeight: FontWeight.w700,
  );
  static const body = TextStyle(fontSize: 14, height: 1.5);
  static const bodyEmphasis = TextStyle(
    fontSize: 14,
    height: 1.5,
    fontWeight: FontWeight.w600,
  );
  static const bodySmall = TextStyle(fontSize: 12, height: 1.5);
  static const caption = TextStyle(
    fontSize: 12,
    height: 1.4,
    fontWeight: FontWeight.w600,
  );
  static const micro = TextStyle(fontSize: 12, height: 1.4);
  static const section = TextStyle(
    fontSize: 12,
    height: 1.5,
    fontWeight: FontWeight.w700,
    letterSpacing: .8,
  );
  static const button = TextStyle(fontSize: 14, fontWeight: FontWeight.w700);
  static const badge = TextStyle(
    fontSize: 12,
    height: 1.4,
    fontWeight: FontWeight.w700,
  );
  static const navigation = TextStyle(
    fontSize: 12,
    height: 1.4,
    fontWeight: FontWeight.w600,
  );
  static const timecode = TextStyle(
    fontFamily: AppFonts.monospace,
    fontSize: 12,
    height: 1.5,
  );
}

abstract final class AppTheme {
  static final dark = _build(StudioColors.dark, Brightness.dark);
  static final light = _build(StudioColors.light, Brightness.light);

  static ThemeData _build(StudioColors c, Brightness brightness) {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: c.primary,
          brightness: brightness,
        ).copyWith(
          primary: c.primary,
          onPrimary: c.primaryForeground,
          primaryContainer: c.primary.withValues(alpha: .14),
          onPrimaryContainer: c.text,
          secondary: c.cyan,
          onSecondary: c.background,
          surface: c.surface,
          onSurface: c.text,
          onSurfaceVariant: c.muted,
          surfaceContainerLowest: c.background,
          surfaceContainerLow: c.card,
          surfaceContainer: c.elevated,
          surfaceContainerHigh: c.elevated,
          surfaceContainerHighest: c.overlay,
          outline: c.outline,
          outlineVariant: c.border,
          error: c.warning,
          onError: c.background,
        );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.control),
    );
    final text =
        const TextTheme(
          displayLarge: AppTypography.display,
          headlineLarge: AppTypography.headline,
          headlineMedium: AppTypography.headline,
          titleLarge: AppTypography.headline,
          titleMedium: AppTypography.title,
          titleSmall: AppTypography.bodyEmphasis,
          bodyLarge: AppTypography.body,
          bodyMedium: AppTypography.body,
          bodySmall: AppTypography.bodySmall,
          labelLarge: AppTypography.button,
          labelMedium: AppTypography.caption,
          labelSmall: AppTypography.micro,
        ).apply(
          fontFamily: AppFonts.family,
          bodyColor: c.text,
          displayColor: c.text,
        );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      extensions: [c],
      fontFamily: AppFonts.family,
      textTheme: text,
      scaffoldBackgroundColor: c.background,
      canvasColor: c.surface,
      disabledColor: c.disabled,
      dividerColor: c.border,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      iconTheme: IconThemeData(color: c.text, size: AppIconSize.large),
      actionIconTheme: ActionIconThemeData(
        backButtonIconBuilder: (_) => const Icon(AppIcons.back),
        closeButtonIconBuilder: (_) => const Icon(AppIcons.close),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        foregroundColor: c.text,
        surfaceTintColor: Colors.transparent,
        elevation: AppElevation.flat,
        titleTextStyle: text.titleMedium,
        systemOverlayStyle: overlayStyle(brightness, c.background),
      ),
      cardTheme: CardThemeData(
        color: c.card,
        elevation: AppElevation.flat,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(color: c.border),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: c.muted,
        textColor: c.text,
        minTileHeight: AppSize.settingsRow,
        titleTextStyle: text.bodyLarge,
        subtitleTextStyle: text.bodySmall?.copyWith(color: c.muted),
        shape: shape,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(AppSize.touchTarget, AppSize.button),
          shape: shape,
          textStyle: AppTypography.button,
          animationDuration: AppMotion.fast,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(AppSize.touchTarget, AppSize.touchTarget),
          foregroundColor: c.text,
          side: BorderSide(color: c.outline),
          shape: shape,
          textStyle: AppTypography.bodyEmphasis,
          animationDuration: AppMotion.fast,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.primary,
          minimumSize: const Size(AppSize.touchTarget, AppSize.touchTarget),
          shape: shape,
          textStyle: AppTypography.bodyEmphasis,
          animationDuration: AppMotion.fast,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: c.text,
          minimumSize: const Size.square(AppSize.touchTarget),
          tapTargetSize: MaterialTapTargetSize.padded,
          animationDuration: AppMotion.fast,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surface,
        selectedColor: c.primary.withValues(alpha: .14),
        disabledColor: c.elevated,
        side: BorderSide(color: c.outline),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        labelStyle: text.bodySmall,
        secondaryLabelStyle: text.bodySmall?.copyWith(color: c.primary),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        showCheckmark: false,
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: c.surface,
        contentPadding: const EdgeInsets.all(AppSpacing.md),
        hintStyle: text.bodyMedium?.copyWith(color: c.muted),
        labelStyle: text.bodyMedium?.copyWith(color: c.muted),
        prefixIconColor: c.muted,
        suffixIconColor: c.muted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: BorderSide(color: c.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: BorderSide(color: c.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: BorderSide(color: c.primary, width: AppBorder.focused),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: BorderSide(color: c.warning),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.elevated,
        surfaceTintColor: Colors.transparent,
        elevation: AppElevation.dialog,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.feature),
          side: BorderSide(color: c.border),
        ),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium?.copyWith(color: c.muted),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        modalBackgroundColor: c.surface,
        modalBarrierColor: AppColors.mediaScrim,
        surfaceTintColor: Colors.transparent,
        elevation: AppElevation.floating,
        showDragHandle: true,
        dragHandleColor: c.muted,
        dragHandleSize: const Size(36, 4),
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.feature),
          ),
          side: BorderSide(color: c.border),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.elevated,
        surfaceTintColor: Colors.transparent,
        shape: shape,
        textStyle: text.bodyMedium,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: c.cyan,
        thumbColor: c.cyan,
        inactiveTrackColor: c.overlay,
        overlayColor: c.cyan.withValues(alpha: .12),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.primary,
        linearTrackColor: c.overlay,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.elevated,
        contentTextStyle: text.bodyMedium,
        actionTextColor: c.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          side: BorderSide(color: c.outline),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.primary,
        foregroundColor: c.primaryForeground,
        elevation: AppElevation.flat,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: StudioPageTransitions(),
          TargetPlatform.iOS: StudioPageTransitions(),
        },
      ),
    );
  }

  static SystemUiOverlayStyle overlayStyle(
    Brightness brightness,
    Color background,
  ) => SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: brightness == Brightness.dark
        ? Brightness.light
        : Brightness.dark,
    statusBarBrightness: brightness,
    systemNavigationBarColor: background,
    systemNavigationBarIconBrightness: brightness == Brightness.dark
        ? Brightness.light
        : Brightness.dark,
  );
}

class StudioPageTransitions extends PageTransitionsBuilder {
  const StudioPageTransitions();
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (context.reduceMotion) return child;
    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: AppMotion.enter),
      child: child,
    );
  }
}
