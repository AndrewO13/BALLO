import 'package:flutter/services.dart';

import 'referee_whistle_player.dart';

/// Plays the bundled referee whistle and haptics (half-time / stoppage time).
Future<void> playStoppageAlert() async {
  await RefereeWhistlePlayer.instance.play();
  await HapticFeedback.heavyImpact();
}
