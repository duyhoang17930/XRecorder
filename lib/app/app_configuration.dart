import 'package:flutter/material.dart';

/// Only advertise appearance/language resources that the app actually ships.
abstract final class AppConfiguration {
  static const locale = Locale('en');
  static const supportedLocales = [locale];
  static const themeMode = ThemeMode.dark;
}
