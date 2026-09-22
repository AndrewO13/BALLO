import 'package:flutter/material.dart';

/// Animates [controller] to the top if it is attached to a scroll view.
Future<void> animateScrollControllerToTop(
  ScrollController controller, {
  Duration duration = const Duration(milliseconds: 300),
  Curve curve = Curves.easeOutCubic,
}) async {
  if (!controller.hasClients) return;
  await controller.animateTo(0, duration: duration, curve: curve);
}
