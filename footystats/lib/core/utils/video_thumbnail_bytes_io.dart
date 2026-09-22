import 'dart:typed_data';

import 'package:video_thumbnail/video_thumbnail.dart';

Future<Uint8List?> generateVideoThumbnailBytes({
  required String videoPath,
  int maxWidth = 720,
  int quality = 75,
  int timeMs = 300,
}) {
  return VideoThumbnail.thumbnailData(
    video: videoPath,
    imageFormat: ImageFormat.JPEG,
    maxWidth: maxWidth,
    quality: quality,
    timeMs: timeMs,
  );
}
