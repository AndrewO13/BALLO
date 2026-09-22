import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:video_player/video_player.dart';

import 'explore_video_controller_io.dart'
    if (dart.library.html) 'explore_video_controller_web.dart' as impl;

Future<VideoPlayerController> createExploreVideoController({
  required String videoUrl,
  required String videoId,
  required BaseCacheManager cacheManager,
}) {
  return impl.createExploreVideoController(
    videoUrl: videoUrl,
    videoId: videoId,
    cacheManager: cacheManager,
  );
}
