import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:beep_sound/beep_sound.dart';
import 'package:flutter/services.dart';

AudioPlayer? _whistlePlayer;

/// Mobile: plays referee whistle (asset) or fallback beep, plus haptics.
void playStoppageAlert() {
  _whistlePlayer ??= AudioPlayer();
  _whistlePlayer!.play(AssetSource('lib/assets/sounds/referee_whistle.mp3')).catchError((_) {
    _playFallbackBeep();
  });
  HapticFeedback.heavyImpact();
}

void _playFallbackBeep() {
  if (Platform.isAndroid) {
    BeepSound().playSysSound(AndroidSoundIDs.toneCdmaAbbrAlert.value);
  } else if (Platform.isIOS) {
    BeepSound().playSysSound(IOSSoundID.mailReceived.value);
  } else {
    SystemSound.play(SystemSoundType.click);
  }
}
