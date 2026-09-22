import 'picked_video_io.dart'
    if (dart.library.html) 'picked_video_web.dart' as impl;

Future<int?> readVideoDurationSeconds(String videoPath) {
  return impl.readVideoDurationSeconds(videoPath);
}
