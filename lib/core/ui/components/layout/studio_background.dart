import 'package:flutter/material.dart';

import '../../theme/colors.dart';

/// Ambient app backdrop: a soft top wash, two blurred brand glows and a faint
/// dot grid that fades out down the screen.
///
/// It is static and isolated in its own layer, so scrolling content above it
/// never repaints it.
class StudioBackground extends StatelessWidget {
  const StudioBackground({super.key, this.child});
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final backdrop = IgnorePointer(
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: CustomPaint(
            size: Size.infinite,
            painter: _BackdropPainter(
              colors: context.studioColors,
              dark: Theme.of(context).brightness == Brightness.dark,
            ),
          ),
        ),
      ),
    );
    if (child == null) return backdrop;
    return Stack(fit: StackFit.expand, children: [backdrop, child!]);
  }
}

class _BackdropPainter extends CustomPainter {
  const _BackdropPainter({required this.colors, required this.dark});
  final StudioColors colors;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;

    // Base: background with a barely-there brand tint at the top.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0, .45, 1],
          colors: [
            Color.alphaBlend(
              colors.primary.withValues(alpha: dark ? .08 : .06),
              colors.background,
            ),
            colors.background,
            colors.background,
          ],
        ).createShader(rect),
    );

    final reach = size.shortestSide;
    _glow(
      canvas,
      center: Offset(size.width * .95, -reach * .02),
      radius: reach * 1.15,
      color: colors.primary,
      alpha: dark ? .26 : .17,
    );
    _glow(
      canvas,
      center: Offset(-reach * .15, size.height * .5),
      radius: reach * .95,
      color: colors.cyan,
      alpha: dark ? .13 : .1,
    );
    _glow(
      canvas,
      center: Offset(size.width * 1.05, size.height * .88),
      radius: reach * .9,
      color: colors.primary,
      alpha: dark ? .12 : .08,
    );

    // Faint dot grid, fading out by halfway down.
    const gap = 22.0;
    final fadeEnd = size.height * .5;
    final dot = Paint();
    final base = colors.text.withValues(alpha: dark ? .16 : .18);
    for (var y = gap / 2; y < fadeEnd; y += gap) {
      final t = 1 - y / fadeEnd;
      dot.color = base.withValues(alpha: base.a * t * t);
      for (var x = gap / 2; x < size.width; x += gap) {
        canvas.drawCircle(Offset(x, y), 1.1, dot);
      }
    }
  }

  void _glow(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required Color color,
    required double alpha,
  }) {
    final bounds = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: alpha),
            color.withValues(alpha: alpha * .35),
            color.withValues(alpha: 0),
          ],
          stops: const [0, .45, 1],
        ).createShader(bounds),
    );
  }

  @override
  bool shouldRepaint(_BackdropPainter old) =>
      old.colors != colors || old.dark != dark;
}
