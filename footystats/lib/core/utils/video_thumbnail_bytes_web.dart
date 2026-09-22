import 'dart:async';
import 'dart:js_interop';
import 'dart:convert';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<Uint8List?> generateVideoThumbnailBytes({
  required String videoPath,
  int maxWidth = 720,
  int quality = 75,
  int timeMs = 300,
}) async {
  final video = web.document.createElement('video') as web.HTMLVideoElement;
  video.preload = 'auto';
  video.muted = true;
  video.playsInline = true;
  video.src = videoPath;

  try {
    await _waitForEvent(video, 'loadedmetadata');
    final durationMs = (video.duration.isFinite ? video.duration * 1000 : 0)
        .round();
    final seekMs = durationMs > 0 ? timeMs.clamp(0, durationMs) : 0;
    video.currentTime = seekMs / 1000.0;
    await _waitForEvent(video, 'seeked');

    final aspect = video.videoWidth / video.videoHeight;
    final canvas = web.document.createElement('canvas') as web.HTMLCanvasElement;
    canvas.width = maxWidth;
    canvas.height = (maxWidth / aspect).round().clamp(1, 100000);
    final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D;
    ctx.drawImage(video, 0, 0, canvas.width.toDouble(), canvas.height.toDouble());

    final dataUrl = canvas.toDataURL('image/jpeg');
    return _dataUrlToBytes(dataUrl);
  } catch (_) {
    return null;
  } finally {
    video.src = '';
    video.remove();
  }
}

Future<void> _waitForEvent(web.EventTarget target, String type) {
  final completer = Completer<void>();
  late web.EventListener listener;
  listener = ((web.Event event) {
    target.removeEventListener(type, listener);
    completer.complete();
  }).toJS;
  target.addEventListener(type, listener);
  target.addEventListener(
    'error',
    ((web.Event event) {
      if (!completer.isCompleted) {
        target.removeEventListener(type, listener);
        completer.completeError(StateError('Video thumbnail failed'));
      }
    }).toJS,
  );
  return completer.future.timeout(
    const Duration(seconds: 15),
    onTimeout: () => throw TimeoutException('Video thumbnail timed out'),
  );
}

Uint8List _dataUrlToBytes(String dataUrl) {
  final commaIndex = dataUrl.indexOf(',');
  if (commaIndex == -1) {
    throw FormatException('Invalid data URL');
  }
  return base64Decode(dataUrl.substring(commaIndex + 1));
}
