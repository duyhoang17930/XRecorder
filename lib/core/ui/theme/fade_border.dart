import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// The studio's signature edge: a rounded hairline that is strongest along the
/// bottom and fades out toward the top.
///
/// It is a [ShapeBorder], so themes can hand it to dialogs, menus, sheets,
/// snack bars and cards, and [Material] clips and paints with it directly.
class FadeBorder extends OutlinedBorder {
  const FadeBorder({
    this.borderRadius = BorderRadius.zero,
    required this.color,
    this.bottomAlpha = .5,
    this.topAlpha = .1,
    this.width = 1,
  }) : super(side: BorderSide.none);

  final BorderRadiusGeometry borderRadius;
  final Color color;
  final double bottomAlpha;
  final double topAlpha;
  final double width;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(width);

  RRect _rrect(Rect rect, TextDirection? textDirection) =>
      borderRadius.resolve(textDirection).toRRect(rect);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRRect(_rrect(rect, textDirection).deflate(width));

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRRect(_rrect(rect, textDirection));

  @override
  bool get preferPaintInterior => true;

  @override
  void paintInterior(
    Canvas canvas,
    Rect rect,
    Paint paint, {
    TextDirection? textDirection,
  }) {
    canvas.drawRRect(_rrect(rect, textDirection), paint);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (width <= 0 || rect.isEmpty) return;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          color.withValues(alpha: color.a * bottomAlpha),
          color.withValues(alpha: color.a * topAlpha),
        ],
      ).createShader(rect);
    canvas.drawRRect(_rrect(rect, textDirection).deflate(width / 2), stroke);
  }

  @override
  FadeBorder copyWith({
    BorderSide? side,
    BorderRadiusGeometry? borderRadius,
    Color? color,
    double? width,
  }) => FadeBorder(
    borderRadius: borderRadius ?? this.borderRadius,
    color: color ?? this.color,
    bottomAlpha: bottomAlpha,
    topAlpha: topAlpha,
    width: width ?? side?.width ?? this.width,
  );

  @override
  ShapeBorder scale(double t) => FadeBorder(
    borderRadius: borderRadius * t,
    color: color,
    bottomAlpha: bottomAlpha,
    topAlpha: topAlpha,
    width: width * t,
  );

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is FadeBorder) return _lerp(a, this, t);
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is FadeBorder) return _lerp(this, b, t);
    return super.lerpTo(b, t);
  }

  static FadeBorder _lerp(FadeBorder a, FadeBorder b, double t) => FadeBorder(
    borderRadius: BorderRadiusGeometry.lerp(a.borderRadius, b.borderRadius, t)!,
    color: Color.lerp(a.color, b.color, t)!,
    bottomAlpha: lerpDouble(a.bottomAlpha, b.bottomAlpha, t)!,
    topAlpha: lerpDouble(a.topAlpha, b.topAlpha, t)!,
    width: lerpDouble(a.width, b.width, t)!,
  );

  @override
  bool operator ==(Object other) =>
      other is FadeBorder &&
      other.borderRadius == borderRadius &&
      other.color == color &&
      other.bottomAlpha == bottomAlpha &&
      other.topAlpha == topAlpha &&
      other.width == width;

  @override
  int get hashCode =>
      Object.hash(borderRadius, color, bottomAlpha, topAlpha, width);
}

/// Theme-tuned [FadeBorder] built from the studio outline colour.
FadeBorder studioFadeBorder({
  required Color outline,
  required bool dark,
  BorderRadiusGeometry borderRadius = BorderRadius.zero,
  double strength = 1,
}) => FadeBorder(
  borderRadius: borderRadius,
  color: outline,
  bottomAlpha: (dark ? .55 : .45) * strength,
  topAlpha: (dark ? .12 : .08) * strength,
);
