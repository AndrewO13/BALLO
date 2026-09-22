import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Story-style capsule ring around the score pill when [hasVideo].
///
/// The ring is split into equal WhatsApp-style segments, one per match video.
/// Unwatched segments keep the green gradient; watched segments turn grey.
class MatchListScorePill extends StatelessWidget {
  const MatchListScorePill({
    super.key,
    required this.scoreText,
    required this.hasVideo,
    this.videoWatched = const [],
  });

  final String scoreText;
  final bool hasVideo;

  /// One entry per video, in upload order. `true` means that clip was watched.
  final List<bool> videoWatched;

  static const double _ringWidth = 2.5;

  /// Original video highlight green — anchor for the story ring.
  static const Color _videoHighlightGreen = Color(0xFF00FF5A);

  /// Soft story-like sweep through brand greens and teal accents.
  static Gradient videoStoryRingGradient(ColorScheme scheme) {
    return SweepGradient(
      colors: [
        _videoHighlightGreen,
        scheme.inversePrimary,
        scheme.primaryFixed,
        scheme.secondaryContainer,
        scheme.tertiaryFixedDim,
        _videoHighlightGreen,
      ],
      stops: const [0.0, 0.22, 0.44, 0.64, 0.84, 1.0],
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final text = Text(
      scoreText,
      style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
    );

    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: text,
    );

    if (hasVideo) {
      final segments = videoWatched.isEmpty ? const [false] : videoWatched;
      return CustomPaint(
        painter: _StadiumStatusRingPainter(
          watched: segments,
          strokeWidth: _ringWidth,
          unreadGradient: videoStoryRingGradient(colorScheme),
          watchedColor: colorScheme.onSurface.withValues(
            alpha: colorScheme.brightness == Brightness.dark ? 0.42 : 0.28,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(_ringWidth),
          child: pill,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: text,
    );
  }
}

class _StadiumStatusRingPainter extends CustomPainter {
  _StadiumStatusRingPainter({
    required this.watched,
    required this.strokeWidth,
    required this.unreadGradient,
    required this.watchedColor,
  });

  final List<bool> watched;
  final double strokeWidth;
  final Gradient unreadGradient;
  final Color watchedColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final inset = strokeWidth / 2;
    final rect = Rect.fromLTWH(
      inset,
      inset,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    if (rect.width <= 0 || rect.height <= 0) return;

    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(rect.height / 2),
    );
    final path = Path()..addRRect(rrect);
    ui.PathMetric? metric;
    for (final item in path.computeMetrics()) {
      metric = item;
      break;
    }
    if (metric == null) return;
    final total = metric.length;
    if (total <= 0) return;

    final unreadPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..shader = unreadGradient.createShader(Offset.zero & size);

    final watchedPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = watchedColor;

    final count = watched.length;
    if (count <= 1) {
      canvas.drawPath(
        path,
        (watched.isEmpty || !watched.first) ? unreadPaint : watchedPaint,
      );
      return;
    }

    final gap = (count >= 10 ? 3.2 : 5.0).clamp(2.6, total / (count * 4));
    final usable = total - gap * count;
    if (usable <= 0) {
      canvas.drawPath(path, unreadPaint);
      return;
    }
    final segmentLen = usable / count;
    // addRRect starts at the left end of the top edge; shift so a gap sits
    // near the top-center, like WhatsApp.
    final topCenter = ((rect.width - rect.height) / 2).clamp(0.0, total);

    for (var i = 0; i < count; i++) {
      final start = (topCenter + i * (segmentLen + gap) + gap / 2) % total;
      final end = start + segmentLen;
      final paint = watched[i] ? watchedPaint : unreadPaint;
      _drawMetricSpan(canvas, metric, total, start, end, paint);
    }
  }

  void _drawMetricSpan(
    Canvas canvas,
    ui.PathMetric metric,
    double total,
    double start,
    double end,
    Paint paint,
  ) {
    if (end <= total) {
      canvas.drawPath(metric.extractPath(start, end), paint);
      return;
    }
    canvas.drawPath(metric.extractPath(start, total), paint);
    canvas.drawPath(metric.extractPath(0, end - total), paint);
  }

  @override
  bool shouldRepaint(covariant _StadiumStatusRingPainter oldDelegate) {
    return strokeWidth != oldDelegate.strokeWidth ||
        watchedColor != oldDelegate.watchedColor ||
        unreadGradient != oldDelegate.unreadGradient ||
        !_listEquals(watched, oldDelegate.watched);
  }

  static bool _listEquals(List<bool> a, List<bool> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
