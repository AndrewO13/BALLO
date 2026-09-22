
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../constants/app_assets.dart';

/// Bundled referee whistle — preloaded bytes + [PlayerMode.mediaPlayer].
///
/// Using [BytesSource] avoids fragile asset-path resolution on Android/iOS.
class RefereeWhistlePlayer {
  RefereeWhistlePlayer._();

  static final RefereeWhistlePlayer instance = RefereeWhistlePlayer._();

  AudioPlayer? _player;
  Uint8List? _bytes;
  bool _configured = false;
  DateTime? _lastPlayedAt;

  Future<void> warmUp() async {
    if (_bytes != null && _player != null) return;
    try {
      final data = await rootBundle.load(AppAssets.refereeWhistleSound);
      _bytes = data.buffer.asUint8List();
      _player ??= AudioPlayer();
      await _configurePlayer(_player!);
    } catch (e, st) {
      debugPrint('RefereeWhistlePlayer warmUp failed: $e\n$st');
    }
  }

  Future<void> _configurePlayer(AudioPlayer player) async {
    if (_configured) return;
    await player.setPlayerMode(PlayerMode.mediaPlayer);
    await player.setReleaseMode(ReleaseMode.stop);
    await player.setVolume(1.0);
    if (!kIsWeb) {
      await player.setAudioContext(
        AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: {AVAudioSessionOptions.mixWithOthers},
          ),
          android: AudioContextAndroid(
            isSpeakerphoneOn: true,
            stayAwake: false,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.media,
            audioFocus: AndroidAudioFocus.gain,
          ),
        ),
      );
    }
    _configured = true;
  }

  /// Plays the bundled whistle. Ignores repeat calls within 2 seconds.
  Future<void> play() async {
    final now = DateTime.now();
    if (_lastPlayedAt != null &&
        now.difference(_lastPlayedAt!) < const Duration(seconds: 2)) {
      return;
    }

    if (_bytes == null || _player == null) {
      await warmUp();
    }
    final bytes = _bytes;
    final player = _player;
    if (bytes == null || player == null) return;

    try {
      _lastPlayedAt = now;
      await player.stop();
      await player.play(BytesSource(bytes));
    } catch (e, st) {
      debugPrint('RefereeWhistlePlayer play failed: $e\n$st');
    }
  }
}
