import 'package:flutter/material.dart';

import 'colors.dart';

abstract final class AppElevation {
  static const flat = 0.0;
  static const floating = 2.0;
  static const dialog = 6.0;
}

abstract final class AppShadows {
  static List<BoxShadow> card(BuildContext context) => [
    BoxShadow(
      color: context.studioColors.primary.withValues(alpha: .035),
      blurRadius: 14,
      offset: const Offset(0, 5),
    ),
  ];

  static List<BoxShadow> search(BuildContext context) => [
    BoxShadow(
      color: context.studioColors.primary.withValues(alpha: .07),
      blurRadius: 8,
      offset: const Offset(0, 3),
    ),
  ];
}
