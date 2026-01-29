import 'dart:math' as math;
import 'package:flutter/material.dart';

class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.size,
    required this.progress,
    required this.valueText,
    required this.labelText,
    this.icon,
  });

  final double size;
  final double progress; // 0..1
  final String valueText;
  final String labelText;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    // Separate positioning for large (163) and small (75) rings
    final bool isLarge = size >= 163;
    final double iconSize = isLarge ? 70 : 32;
    final double topOffset = isLarge ? 65 : 52;
    final double bottomOffset = isLarge ? -2 : 6;
    final double extraHeight = isLarge ? 30 : 65;

    // Determine value text style based on ring size
    final valueTextStyle = size >= 163
        ? textTheme.displaySmall?.copyWith(height: 1.0)
        : textTheme.headlineSmall?.copyWith(height: 1.0);

    // Label text style for all rings
    final labelTextStyle = textTheme.labelLarge?.copyWith();

    final defaultIcon = Icon(
      Icons.sports_soccer,
      size: iconSize,
      color: Colors.white,
    );

    return SizedBox(
      width: size,
      height: size + extraHeight, // extra space for label
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(progress: progress, ringSize: size),
          ),
          // Center icon
          Positioned(
            top: topOffset,
            child: icon != null
                ? SizedBox(width: iconSize, height: iconSize, child: icon)
                : defaultIcon,
          ),
          Positioned(
            bottom: bottomOffset,
            child: Column(
              children: [
                Text(valueText, style: valueTextStyle),
                const SizedBox(height: 2),
                Text(labelText, style: labelTextStyle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.ringSize});

  final double progress;
  final double ringSize;

  // ===== Exact specs you gave =====
  static const double startAngleDeg = 57.75;

  // "ratio of 83.25%" -> used as a multiplier on sweeps (so the arc is not a full 360°)
  static const double ratio = 0.8325;

  // Sweeps are given as percentages (fractions) and are NEGATIVE.
  static const double whiteBaseSweep = 0.005; // -0.5%
  static const double greenBaseSweep = 0.792; // -79.2%
  static const double whiteSweepAt100 = 0.82; // -82% at 100%

  static const double whiteRotationDeg = 158.75;
  static const double greenRotationDeg = 0.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width, size.height) / 2;

    // Scale stroke width proportionally (14.0 for size 163, scale for others)
    final stroke = (ringSize / 163.0) * 14.0;
    final rect = Rect.fromCircle(center: center, radius: r - stroke / 2);

    final startBase = _degToRad(startAngleDeg);

    // Progress ONLY affects sweep, and both change by the SAME amount (opposite directions).
    // Example rule: white -3% -> -8% means delta = 5%,
    //              green -77.7% -> -72.7% means green increases by 5% (less negative).
    final delta =
        (whiteSweepAt100 - whiteBaseSweep) * progress; // in fraction units

    final whiteSweepFraction = -(whiteBaseSweep - delta); // negative
    final greenSweepFraction =
        -(greenBaseSweep - delta); // negative until it hits 0 remaining

    // Clamp green so it never flips direction once fully covered
    final greenSweepFractionClamped = math.min(0.0, greenSweepFraction);

    final whiteStart = startBase + _degToRad(whiteRotationDeg);
    final greenStart = startBase + _degToRad(greenRotationDeg);

    final whiteSweep = whiteSweepFraction * ratio * math.pi * 2;
    final greenSweep = greenSweepFractionClamped * ratio * math.pi * 2;

    final greenPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xff006a37);

    final whitePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xfff2fff1);

    // Draw remaining (green) first, then current progress (white) on top.
    if (greenSweep != 0) {
      canvas.drawArc(rect, greenStart, greenSweep, false, greenPaint);
    }
    if (whiteSweep != 0) {
      canvas.drawArc(rect, whiteStart, whiteSweep, false, whitePaint);
    }

    // Small marker dot at the white ring start (matches the "dot" at the start position).
    final dotAngle = whiteStart;
    final dotRadius = (r - stroke / 2);
    final dotCenter = Offset(
      center.dx + dotRadius * math.cos(dotAngle),
      center.dy + dotRadius * math.sin(dotAngle),
    );

    canvas.drawCircle(
      dotCenter,
      stroke * 0.45,
      Paint()..color = const Color(0xfff2fff1),
    );
  }

  double _degToRad(double deg) => deg * math.pi / 270.0;

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.ringSize != ringSize;
  }
}
