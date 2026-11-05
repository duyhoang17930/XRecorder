import 'package:flutter/material.dart';

/// Fixed media paint; app surfaces use the brightness-aware StudioColors.
abstract final class AppColors {
  static const mediaBackground = Color(0xFF000000);
  static const onMedia = Color(0xFFFFFFFF);
  static const mediaScrim = Color(0xB8000000);
}

@immutable
class StudioColors extends ThemeExtension<StudioColors> {
  const StudioColors({
    required this.background,
    required this.surface,
    required this.card,
    required this.elevated,
    required this.overlay,
    required this.primary,
    required this.primaryForeground,
    required this.cyan,
    required this.warning,
    required this.text,
    required this.muted,
    required this.disabled,
    required this.border,
    required this.outline,
    required this.recording,
    required this.onRecording,
  });
  final Color background;
  final Color surface;
  final Color card;
  final Color elevated;
  final Color overlay;
  final Color primary;
  final Color primaryForeground;
  final Color cyan;
  final Color warning;
  final Color text;
  final Color muted;
  final Color disabled;
  final Color border;
  final Color outline;
  final Color recording;
  final Color onRecording;
  static const dark = StudioColors(
    background: Color(0xFF0C1018),
    surface: Color(0xFF141A26),
    card: Color(0xFF181E2A),
    elevated: Color(0xFF242D3E),
    overlay: Color(0xFF303B50),
    primary: Color(0xFFFF7948),
    primaryForeground: Color(0xFF391300),
    cyan: Color(0xFF55DCC5),
    warning: Color(0xFFFF8490),
    text: Color(0xFFF5F7FC),
    muted: Color(0xFFA6B0C3),
    disabled: Color(0xFF8490A6),
    border: Color(0xFF303B50),
    outline: Color(0xFF64738F),
    recording: Color(0xFFFF6670),
    onRecording: Color(0xFF35070B),
  );
  static const light = StudioColors(
    background: Color(0xFFF3F5FA),
    surface: Color(0xFFFFFFFF),
    card: Color(0xFFFFFFFF),
    elevated: Color(0xFFE7ECF5),
    overlay: Color(0xFFDBE2EE),
    primary: Color(0xFFA83A12),
    primaryForeground: Color(0xFFFFFFFF),
    cyan: Color(0xFF006B5F),
    warning: Color(0xFFB3263A),
    text: Color(0xFF182033),
    muted: Color(0xFF526078),
    disabled: Color(0xFF68748A),
    border: Color(0xFFD5DDEA),
    outline: Color(0xFF78869C),
    recording: Color(0xFFBB2335),
    onRecording: Color(0xFFFFFFFF),
  );
  @override
  StudioColors copyWith({
    Color? background,
    Color? surface,
    Color? card,
    Color? elevated,
    Color? overlay,
    Color? primary,
    Color? primaryForeground,
    Color? cyan,
    Color? warning,
    Color? text,
    Color? muted,
    Color? disabled,
    Color? border,
    Color? outline,
    Color? recording,
    Color? onRecording,
  }) => StudioColors(
    background: background ?? this.background,
    surface: surface ?? this.surface,
    card: card ?? this.card,
    elevated: elevated ?? this.elevated,
    overlay: overlay ?? this.overlay,
    primary: primary ?? this.primary,
    primaryForeground: primaryForeground ?? this.primaryForeground,
    cyan: cyan ?? this.cyan,
    warning: warning ?? this.warning,
    text: text ?? this.text,
    muted: muted ?? this.muted,
    disabled: disabled ?? this.disabled,
    border: border ?? this.border,
    outline: outline ?? this.outline,
    recording: recording ?? this.recording,
    onRecording: onRecording ?? this.onRecording,
  );
  @override
  StudioColors lerp(StudioColors? other, double t) {
    if (other == null) return this;
    return StudioColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      card: Color.lerp(card, other.card, t)!,
      elevated: Color.lerp(elevated, other.elevated, t)!,
      overlay: Color.lerp(overlay, other.overlay, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryForeground: Color.lerp(
        primaryForeground,
        other.primaryForeground,
        t,
      )!,
      cyan: Color.lerp(cyan, other.cyan, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      text: Color.lerp(text, other.text, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      disabled: Color.lerp(disabled, other.disabled, t)!,
      border: Color.lerp(border, other.border, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      recording: Color.lerp(recording, other.recording, t)!,
      onRecording: Color.lerp(onRecording, other.onRecording, t)!,
    );
  }
}

extension StudioThemeContext on BuildContext {
  StudioColors get studioColors =>
      Theme.of(this).extension<StudioColors>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? StudioColors.dark
          : StudioColors.light);
  bool get reduceMotion => MediaQuery.disableAnimationsOf(this);
  Duration motion(Duration duration) => reduceMotion ? Duration.zero : duration;
}

abstract final class AppSpacing {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
}

abstract final class AppRadius {
  static const card = 20.0;
  static const feature = 28.0;
  static const control = 14.0;
  static const icon = 12.0;
  static const waveform = 2.0;
  static const pill = 9999.0;
}

abstract final class AppElevation {
  static const flat = 0.0;
  static const floating = 2.0;
  static const dialog = 6.0;
}

abstract final class AppBorder {
  static const subtle = 1.0;
  static const focused = 2.0;
}

abstract final class AppSize {
  static const touchTarget = 48.0;
  static const button = 52.0;
  static const navigation = 76.0;
  static const create = 52.0;
  static const settingsRow = 72.0;
  static const thumbnailWidth = 92.0;
  static const thumbnailHeight = 72.0;
  static const timeline = 124.0;
  static const bentoMinimum = 164.0;
  static const emptyIcon = 64.0;
  static const navigationLabelScale = 1.3;
}

abstract final class AppBreakpoints {
  static const compact = 340.0;
  static const tablet = 600.0;
  static const wide = 900.0;
  static const content = 1100.0;
}

abstract final class AppMotion {
  static const fast = Duration(milliseconds: 120);
  static const standard = Duration(milliseconds: 180);
  static const slow = Duration(milliseconds: 280);
  static const enter = Curves.easeOutCubic;
  static const exit = Curves.easeInCubic;
  static const emphasized = Curves.easeInOutCubic;
}

abstract final class AppIconSize {
  static const tiny = 18.0;
  static const small = 18.0;
  static const medium = 20.0;
  static const large = 24.0;
  static const primary = 28.0;
  static const feature = 32.0;
  static const preview = 36.0;
  static const featureLarge = 40.0;
  static const hero = 48.0;
}

abstract final class AppFonts {
  static const family = 'Manrope';
  static const monospace = 'monospace';
}

abstract final class AppGradients {
  static const mediaScrim = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Colors.transparent, AppColors.mediaScrim],
  );
}
