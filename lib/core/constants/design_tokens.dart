import 'package:flutter/material.dart';

abstract final class AppColors {
  static const background = Color(0xFF111217);
  static const surface = Color(0xFF1A1B20);
  static const card = Color(0xFF1C1E25);
  static const elevated = Color(0xFF242630);
  static const overlay = Color(0xFF2E303C);
  static const primary = Color(0xFFFF7948);
  static const cyan = Color(0xFF00D2B4);
  static const warning = Color(0xFFFF5353);
  static const text = Color(0xFFFFFFFF);
  static const muted = Color(0xFFA1A4B2);
  static const disabled = Color(0xFF636674);
  static const border = Color(0x14FFFFFF);
}

abstract final class AppSpacing {
  static const xs = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

abstract final class AppRadius {
  static const card = 16.0;
  static const control = 12.0;
  static const pill = 9999.0;
}
