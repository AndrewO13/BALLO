import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

AudioPlayer? _whistlePlayer;

/// Web/desktop: plays referee whistle (asset) or fallback click, plus haptics.
void playStoppageAlert() {
  _whistlePlayer ??= AudioPlayer();
  _whistlePlayer!.play(AssetSource('lib/assets/sounds/referee_whistle.mp3')).catchError((_) {
    SystemSound.play(SystemSoundType.click);
  });
  HapticFeedback.heavyImpact();
}
