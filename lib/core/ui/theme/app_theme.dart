import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../constants/app_icons.dart';
import 'colors.dart';
import 'motion.dart';
import 'radius.dart';
import 'shadows.dart';
import 'spacing.dart';
import 'typography.dart';

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
        backButtonIconBuilder: (context) => Icon(
          Directionality.of(context) == TextDirection.rtl
              ? AppIcons.chevronRight
              : AppIcons.back,
        ),
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
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: BorderSide(color: c.primary, width: 1.5),
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
          borderRadius: BorderRadius.circular(AppRadius.dialog),
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
        dragHandleSize: const Size(40, 3),
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
        elevation: AppElevation.dialog,
        shadowColor: Colors.black.withValues(alpha: .2),
        menuPadding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.menu),
          side: BorderSide(color: c.border),
        ),
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
      opacity: animation.drive(CurveTween(curve: AppMotion.enter)),
      child: child,
    );
  }
}
