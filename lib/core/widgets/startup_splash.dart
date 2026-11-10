import 'package:flutter/material.dart';

import '../ui/theme/colors.dart';
import '../ui/theme/motion.dart';
import '../ui/theme/typography.dart';

/// A short, interruptible brand reveal shown only while startup preferences
/// are being restored. It never holds the app open after initialization.
class StartupSplash extends StatefulWidget {
  const StartupSplash({super.key});

  @override
  State<StartupSplash> createState() => _StartupSplashState();
}

class _StartupSplashState extends State<StartupSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: AppMotion.brandReveal,
  )..forward();

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.studioColors;
    final reducedMotion = context.reduceMotion;
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.light
          ? const Color(0xFFFAF9F6)
          : colors.background,
      body: SafeArea(
        child: Center(
          child: Semantics(
            image: true,
            label: '3HRecorder',
            child: ExcludeSemantics(
              child: AnimatedBuilder(
                animation: _reveal,
                builder: (context, _) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CustomPaint(
                      size: const Size.square(144),
                      painter: HandDrawnLogoPainter(
                        progress: reducedMotion ? 1 : _reveal.value,
                        strokeColor: colors.text,
                        accentColor: colors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Recorder',
                      style: AppTypography.headline.copyWith(
                        color: colors.text,
                        letterSpacing: -.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

@immutable
class HandDrawnLogoPainter extends CustomPainter {
  const HandDrawnLogoPainter({
    required this.progress,
    required this.strokeColor,
    required this.accentColor,
  });

  final double progress;
  final Color strokeColor;
  final Color accentColor;

  static final _three = Path()
    ..moveTo(22, 29)
    ..cubicTo(32, 13, 58, 13, 68, 27)
    ..cubicTo(76, 39, 63, 48, 48, 49)
    ..cubicTo(66, 48, 77, 58, 70, 73)
    ..cubicTo(62, 89, 35, 88, 21, 74);

  static final _h = Path()
    ..moveTo(73, 31)
    ..cubicTo(72, 44, 71, 60, 70, 75)
    ..moveTo(72, 52)
    ..cubicTo(78, 51, 84, 51, 90, 52)
    ..moveTo(90, 31)
    ..cubicTo(89, 45, 88, 60, 87, 75);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final stroke = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.1
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final normalized = progress.clamp(0.0, 1.0);
    _drawReveal(canvas, _three, (normalized / .64).clamp(0.0, 1.0), stroke);
    _drawReveal(canvas, _h, ((normalized - .64) / .36).clamp(0.0, 1.0), stroke);
    if (normalized >= 1) {
      canvas.drawCircle(
        const Offset(93, 76),
        2.1,
        Paint()..color = accentColor,
      );
    }
    canvas.restore();
  }

  void _drawReveal(Canvas canvas, Path path, double progress, Paint paint) {
    if (progress <= 0) return;
    final metrics = path.computeMetrics().toList(growable: false);
    final totalLength = metrics.fold<double>(
      0,
      (sum, metric) => sum + metric.length,
    );
    var remaining = totalLength * progress;
    for (final metric in metrics) {
      if (remaining <= 0) break;
      final length = remaining.clamp(0.0, metric.length);
      canvas.drawPath(metric.extractPath(0, length), paint);
      remaining -= length;
    }
  }

  @override
  bool shouldRepaint(covariant HandDrawnLogoPainter oldDelegate) =>
      progress != oldDelegate.progress ||
      strokeColor != oldDelegate.strokeColor ||
      accentColor != oldDelegate.accentColor;
}
