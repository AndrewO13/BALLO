import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Insets a [NestedScrollView] body by the amount pinned headers paint over it,
/// so the first section of a tab starts below the tab bar and scrolls up to
/// that edge.
class TabBodyUnderlapClip extends StatelessWidget {
  const TabBodyUnderlapClip({
    super.key,
    required this.controller,
    required this.barMaxExtent,
    required this.barMinExtent,
    required this.heroMaxExtent,
    required this.heroMinExtent,
    this.heroPins = true,
    this.trailingMaxExtent = 0,
    this.trailingMinExtent = 0,
    required this.child,
  });

  final ScrollController controller;
  final double barMaxExtent;
  final double barMinExtent;
  final double heroMaxExtent;
  final double heroMinExtent;

  /// False when the hero is a scrolling box, such as the fixture banner,
  /// rather than a pinned header that stays painted over the body.
  final bool heroPins;
  final double trailingMaxExtent;
  final double trailingMinExtent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final viewportFallback = MediaQuery.sizeOf(context).height;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final position = controller.hasClients ? controller.position : null;
        final offset = position != null && position.hasPixels
            ? position.pixels
            : 0.0;
        final viewport = position != null && position.hasViewportDimension
            ? position.viewportDimension
            : viewportFallback;
        final overlap = tabBodyUnderlap(
          offset: offset,
          viewportExtent: viewport,
          barMaxExtent: barMaxExtent,
          barMinExtent: barMinExtent,
          heroMaxExtent: heroMaxExtent,
          heroMinExtent: heroMinExtent,
          heroPins: heroPins,
          trailingMaxExtent: trailingMaxExtent,
          trailingMinExtent: trailingMinExtent,
        );
        return Padding(
          padding: EdgeInsets.only(top: overlap),
          child: child,
        );
      },
      child: child,
    );
  }
}

/// How far the body extends under the painted headers, in the body's coordinates.
double tabBodyUnderlap({
  required double offset,
  required double viewportExtent,
  required double barMaxExtent,
  required double barMinExtent,
  required double heroMaxExtent,
  required double heroMinExtent,
  bool heroPins = true,
  double trailingMaxExtent = 0,
  double trailingMinExtent = 0,
}) {
  var scrollOffset = offset;
  var overlap = 0.0;
  var layoutOffset = 0.0;
  var maxPaintOffset = 0.0;

  void layoutHeader(double maxExtent, double minExtent) {
    if (maxExtent <= 0) return;
    final sliverScrollOffset = math.max(0.0, scrollOffset);
    final shrink = math.min(sliverScrollOffset, maxExtent);
    final childExtent = math.max(minExtent, maxExtent - shrink);
    final constraintsRemaining = math.max(0.0, viewportExtent - layoutOffset);
    final effectiveRemaining = math.max(0.0, constraintsRemaining - overlap);
    final layoutExtent = (maxExtent - sliverScrollOffset).clamp(
      0.0,
      effectiveRemaining,
    );
    final paintExtent = math.min(childExtent, effectiveRemaining);
    final effectiveLayoutOffset = layoutOffset + overlap;
    maxPaintOffset = math.max(
      effectiveLayoutOffset + paintExtent,
      maxPaintOffset,
    );
    scrollOffset -= maxExtent;
    layoutOffset += layoutExtent;
    overlap = maxPaintOffset - layoutOffset;
  }

  void layoutBox(double extent) {
    if (extent <= 0) return;
    final sliverScrollOffset = math.max(0.0, scrollOffset);
    final constraintsRemaining = math.max(0.0, viewportExtent - layoutOffset);
    final windowEnd = sliverScrollOffset + constraintsRemaining;
    final paintExtent =
        (math.min(extent, windowEnd) - math.min(extent, sliverScrollOffset))
            .clamp(0.0, constraintsRemaining);
    maxPaintOffset = math.max(layoutOffset + paintExtent, maxPaintOffset);
    scrollOffset -= extent;
    layoutOffset += paintExtent;
    overlap = maxPaintOffset - layoutOffset;
  }

  layoutHeader(barMaxExtent, barMinExtent);
  if (heroPins) {
    layoutHeader(heroMaxExtent, heroMinExtent);
  } else {
    layoutBox(heroMaxExtent);
  }
  layoutHeader(trailingMaxExtent, trailingMinExtent);
  return math.max(0.0, overlap);
}
