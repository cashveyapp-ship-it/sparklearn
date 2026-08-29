import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class ProgressRing extends StatelessWidget {
  const ProgressRing({super.key, required this.progress, this.size = 132});

  final double progress; // 0..1
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _RingPainter(progress.clamp(0, 1)),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${(progress * 100).round()}%',
                style:
                    const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('weekly goal',
                style: TextStyle(color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.p);
  final double p;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = 12.0;
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (math.min(size.width, size.height) / 2) - stroke;

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = AppColors.ringTrack
      ..strokeCap = StrokeCap.round;

    final progPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = AppColors.indigo
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2,
      false,
      trackPaint,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * p,
      false,
      progPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) => oldDelegate.p != p;
}
