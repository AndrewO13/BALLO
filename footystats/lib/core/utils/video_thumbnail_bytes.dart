import 'dart:typed_data';

import 'video_thumbnail_bytes_io.dart'
    if (dart.library.html) 'video_thumbnail_bytes_web.dart' as impl;

Future<Uint8List?> generateVideoThumbnailBytes({
  required String videoPath,
  int maxWidth = 720,
  int quality = 75,
  int timeMs = 300,
}) {
  return impl.generateVideoThumbnailBytes(
    videoPath: videoPath,
    maxWidth: maxWidth,
    quality: quality,
    timeMs: timeMs,
  );
}
