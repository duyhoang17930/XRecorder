import 'package:flutter/material.dart';

abstract final class AppMotion {
  static const fast = Duration(milliseconds: 120);
  static const standard = Duration(milliseconds: 180);
  static const slow = Duration(milliseconds: 280);
  static const brandReveal = Duration(milliseconds: 850);
  static const enter = Curves.easeOutCubic;
  static const exit = Curves.easeInCubic;
  static const emphasized = Curves.easeInOutCubic;

  static ChipAnimationStyle chipStyle({required bool reduceMotion}) =>
      ChipAnimationStyle(
        selectAnimation: AnimationStyle(
          duration: reduceMotion ? Duration.zero : standard,
          reverseDuration: reduceMotion ? Duration.zero : standard,
        ),
        enableAnimation: AnimationStyle(
          duration: reduceMotion ? Duration.zero : fast,
          reverseDuration: reduceMotion ? Duration.zero : fast,
        ),
        avatarDrawerAnimation: AnimationStyle.noAnimation,
      );
}
