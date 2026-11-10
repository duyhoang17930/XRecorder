import 'package:flutter/material.dart';

import 'colors.dart';

abstract final class AppGradients {
  static const mediaScrim = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Colors.transparent, AppColors.mediaScrim],
  );
}
