import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../constants/app_icons.dart';
import 'colors.dart';
import 'fade_border.dart';
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
          // Material's chip defaults colour a selected chip's icon with this;
          // it must read on the solid primary selected pill.
          onSecondaryContainer: c.primaryForeground,
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
    final dark = brightness == Brightness.dark;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.control),
    );
    // Home-page language: pill controls and hairlines that fade bottom-to-top.
    const pill = StadiumBorder();
    FadeBorder fade(BorderRadiusGeometry radius, {double strength = 1}) =>
        studioFadeBorder(
          outline: c.outline,
          dark: dark,
          borderRadius: radius,
          strength: strength,
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
      // Pages are transparent; XRecorderApp paints StudioBackground behind the
      // navigator so every screen shares one ambient backdrop.
      scaffoldBackgroundColor: Colors.transparent,
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
        backgroundColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.scrolledUnder)
              ? c.background.withValues(alpha: .94)
              : Colors.transparent,
        ),
        scrolledUnderElevation: AppElevation.flat,
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
        shape: fade(BorderRadius.circular(AppRadius.card)),
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
          shape: pill,
          elevation: AppElevation.flat,
          textStyle: text.labelLarge,
          animationDuration: AppMotion.fast,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(AppSize.touchTarget, AppSize.touchTarget),
          foregroundColor: c.text,
          side: BorderSide(color: c.border),
          shape: pill,
          textStyle: text.titleSmall,
          animationDuration: AppMotion.fast,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.primary,
          minimumSize: const Size(AppSize.touchTarget, AppSize.touchTarget),
          shape: pill,
          textStyle: text.titleSmall,
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
      // Soft unselected pills; the selected chip is a solid brand pill.
      chipTheme: ChipThemeData(
        backgroundColor: c.elevated.withValues(alpha: dark ? .7 : 1),
        selectedColor: c.primary,
        disabledColor: c.elevated.withValues(alpha: .5),
        side: const BorderSide(color: Colors.transparent),
        shape: pill,
        elevation: 0,
        pressElevation: 0,
        shadowColor: Colors.transparent,
        selectedShadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        labelStyle: text.labelMedium?.copyWith(
          color: WidgetStateColor.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? c.primaryForeground
                : states.contains(WidgetState.disabled)
                ? c.disabled
                : c.text,
          ),
        ),
        secondaryLabelStyle: text.labelMedium?.copyWith(
          color: c.primaryForeground,
        ),
        checkmarkColor: c.primaryForeground,
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
          borderSide: BorderSide(color: c.border),
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
        backgroundColor: c.card,
        surfaceTintColor: Colors.transparent,
        elevation: AppElevation.dialog,
        shape: fade(BorderRadius.circular(AppRadius.feature)),
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
        dragHandleColor: c.outline.withValues(alpha: .6),
        dragHandleSize: const Size(36, 4),
        shape: fade(
          const BorderRadius.vertical(top: Radius.circular(AppRadius.feature)),
          strength: .8,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: dark ? c.elevated : c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: AppElevation.dialog,
        shadowColor: Colors.black.withValues(alpha: dark ? .35 : .16),
        position: PopupMenuPosition.under,
        menuPadding: const EdgeInsets.all(AppSpacing.xxs + 2),
        shape: fade(BorderRadius.circular(AppRadius.menu + 2)),
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
        shape: fade(BorderRadius.circular(AppRadius.menu)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? c.primaryForeground
              : c.outline,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? c.primary : c.elevated,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.transparent
              : c.border,
        ),
      ),
      expansionTileTheme: ExpansionTileThemeData(
        shape: const Border(),
        collapsedShape: const Border(),
        iconColor: c.muted,
        collapsedIconColor: c.muted,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: dark ? c.overlay : c.text,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        textStyle: text.labelMedium?.copyWith(color: dark ? c.text : c.surface),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xxs + 2,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.primary,
        foregroundColor: c.primaryForeground,
        elevation: AppElevation.flat,
        shape: pill,
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
