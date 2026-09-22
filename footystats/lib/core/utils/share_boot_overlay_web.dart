import 'dart:js_interop';

import 'package:web/web.dart' as web;

bool shareBootHasVideo() {
  final el = web.document.getElementById('share-boot-video');
  if (el == null || !el.isA<web.HTMLVideoElement>()) return false;
  final video = el as web.HTMLVideoElement;
  return video.src.isNotEmpty || video.currentSrc.isNotEmpty;
}

double shareBootPlaybackSeconds() {
  final el = web.document.getElementById('share-boot-video');
  if (el == null || !el.isA<web.HTMLVideoElement>()) return 0;
  return (el as web.HTMLVideoElement).currentTime;
}

void removeShareBootOverlay() {
  final el = web.document.getElementById('share-boot-video');
  if (el != null && el.isA<web.HTMLVideoElement>()) {
    final video = el as web.HTMLVideoElement;
    video.pause();
    video.removeAttribute('src');
    video.load();
  }
  web.document.getElementById('share-boot')?.remove();
}
