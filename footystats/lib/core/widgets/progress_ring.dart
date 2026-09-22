import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../adaptive/adaptive.dart';

class ProgressRing extends StatefulWidget {
  const ProgressRing({
    super.key,
    required this.size,
    required this.progress,
    required this.valueText,
    required this.labelText,
    this.icon,
    this.duration = const Duration(milliseconds: 600),
    this.ringToTextSpacing,
    this.valueToLabelSpacing,
    this.textAreaHeight,
  });

  final double size;
  final double progress; // 0..1
  final String valueText;
  final String labelText;
  final Widget? icon;
  final Duration duration;
  final double? ringToTextSpacing;
  final double? valueToLabelSpacing;
  final double? textAreaHeight;

  @override
  State<ProgressRing> createState() => _ProgressRingState();
}

class _ProgressRingState extends State<ProgressRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;
  double _oldProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    final initial = widget.progress.clamp(0.0, 1.0);
    _animation = Tween<double>(begin: 0, end: initial).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.forward();
    _oldProgress = initial;
  }

  @override
  void didUpdateWidget(covariant ProgressRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress ||
        oldWidget.duration != widget.duration) {
      if (oldWidget.duration != widget.duration) {
        _controller.duration = widget.duration;
      }
      final target = widget.progress.clamp(0.0, 1.0);
      _animation = Tween<double>(begin: _oldProgress, end: target).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      );
      _controller
        ..reset()
        ..forward();
      _oldProgress = target;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final bool isLight = colorScheme.brightness == Brightness.light;
    final Color progressColor =
        isLight ? colorScheme.primary : const Color(0xfff2fff1);
    final Color trackColor =
        isLight ? colorScheme.outlineVariant : const Color(0xff006a37);
    final double size = widget.size * AppResponsive.layoutScaleOf(context);

    // Separate positioning for large (163) and small (75) rings
    final bool isLarge = widget.size >= 163;
    final double iconSize = (isLarge ? 70 : 32) * AppResponsive.layoutScaleOf(context);
    final double resolvedRingToTextSpacing =
        (widget.ringToTextSpacing ?? (isLarge ? 6 : 10)) *
            AppResponsive.layoutScaleOf(context);
    final double resolvedValueToLabelSpacing =
        (widget.valueToLabelSpacing ?? (isLarge ? 4 : 3)) *
            AppResponsive.layoutScaleOf(context);
    final double resolvedTextAreaHeight =
        (widget.textAreaHeight ?? (isLarge ? 66 : 64)) *
            AppResponsive.layoutScaleOf(context);

    // Determine value text style based on ring size
    final valueTextStyle = widget.size >= 163
        ? textTheme.displayMedium?.copyWith(height: 1.0)
        : textTheme.headlineSmall?.copyWith(height: 1.0);

    // Label text style for all rings
    final labelTextStyle = textTheme.titleSmall?.copyWith();

    final defaultIcon = Icon(
      Icons.sports_soccer,
      size: iconSize,
      color: colorScheme.onSurface,
    );

    return SizedBox(
      width: size,
      height: size + resolvedRingToTextSpacing + resolvedTextAreaHeight,
      child: Stack(
        children: [
          AnimatedBuilder(
            animation: _animation,
            builder: (_, _) => CustomPaint(
              size: Size(size, size),
              painter: _RingPainter(
                progress: _animation.value,
                ringSize: size,
                progressColor: progressColor,
                trackColor: trackColor,
              ),
            ),
          ),
          // Center icon
          Positioned(
            top: 0,
            left: 0,
            width: size,
            height: size,
            child: Center(
              child: widget.icon != null
                  ? SizedBox(
                      width: iconSize,
                      height: iconSize,
                      child: IconTheme(
                        data: IconThemeData(
                          color: colorScheme.onSurface,
                          size: iconSize,
                        ),
                        child: widget.icon!,
                      ),
                    )
                  : defaultIcon,
            ),
          ),
          Positioned(
            top: size + resolvedRingToTextSpacing,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.valueText,
                  style: valueTextStyle,
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: resolvedValueToLabelSpacing),
                SizedBox(
                  width: size,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      widget.labelText,
                      style: labelTextStyle,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      softWrap: false,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.ringSize,
    required this.progressColor,
    required this.trackColor,
  });

  final double progress;
  final double ringSize;
  final Color progressColor;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final clamped = progress.clamp(0.0, 1.0);
    final stroke = (ringSize / 163.0) * 14.0;
    final arcRect = (Offset.zero & size).deflate(stroke / 2);
    const gapAngle = 0.25;
    const sweepPercent = 0.8325;
    final maxSweepAngle = 2 * math.pi * sweepPercent;
    final startAngle = (3 * math.pi / 2) - ((maxSweepAngle - gapAngle) / 2);
    final progressSweep = (maxSweepAngle * clamped).clamp(0.0, maxSweepAngle);

    final whiteStart = startAngle;
    final whiteSweep = progressSweep > gapAngle ? progressSweep - gapAngle : 0.0;
    final greenStart = startAngle + progressSweep;
    final greenSweep =
        (maxSweepAngle - progressSweep - gapAngle).clamp(0.0, maxSweepAngle);

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = trackColor;

    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = progressColor;

    if (greenSweep > 0) {
      canvas.drawArc(arcRect, greenStart, greenSweep, false, trackPaint);
    }
    if (whiteSweep > 0) {
      canvas.drawArc(arcRect, whiteStart, whiteSweep, false, progressPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.ringSize != ringSize ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.trackColor != trackColor;
  }
}
