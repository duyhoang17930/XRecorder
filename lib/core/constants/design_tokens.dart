import 'package:flutter/material.dart';

abstract final class AppColors {
  static const background = Color(0xFF111217);
  static const surface = Color(0xFF1A1B20);
  static const card = Color(0xFF1C1E25);
  static const elevated = Color(0xFF242630);
  static const overlay = Color(0xFF2E303C);
  static const primary = Color(0xFFFF7948);
  static const primaryForeground = Color(0xFF391300);
  static const recordForeground = Color(0xFF681E00);
  static const cyan = Color(0xFF00D2B4);
  static const warning = Color(0xFFFF5353);
  static const text = Color(0xFFFFFFFF);
  static const muted = Color(0xFFA1A4B2);
  static const disabled = Color(0xFF636674);
  static const navigationInactive = Color(0xFFDFC0B6);
  static const black = Color(0xFF000000);
  static const black87 = Color(0xDD000000);
  static const border = Color(0x14FFFFFF);
  static const scrim = Color(0xB8000000);
  static const cyanOverlay = Color(0x3300D2B4);
}

abstract final class AppSpacing {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

abstract final class AppRadius {
  static const card = 16.0;
  static const control = 12.0;
  static const icon = 8.0;
  static const waveform = 2.0;
  static const pill = 9999.0;
}

abstract final class AppMotion {
  static const fast = Duration(milliseconds: 150);
  static const standard = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 350);

  static const enter = Curves.easeOutCubic;
  static const exit = Curves.easeInCubic;
  static const emphasized = Curves.easeInOutCubic;
}

abstract final class AppIconSize {
  static const tiny = 14.0;
  static const small = 16.0;
  static const medium = 20.0;
  static const large = 24.0;
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
    colors: [Colors.transparent, AppColors.black87],
  );
  static const photoScrim = LinearGradient(
    begin: Alignment.center,
    end: Alignment.bottomCenter,
    colors: [Colors.transparent, AppColors.black],
  );
}
