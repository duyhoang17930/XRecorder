import 'package:flutter/material.dart';

import 'spacing.dart';

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
