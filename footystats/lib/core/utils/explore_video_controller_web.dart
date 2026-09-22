import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:video_player/video_player.dart';

Future<VideoPlayerController> createExploreVideoController({
  required String videoUrl,
  required String videoId,
  required BaseCacheManager cacheManager,
}) async {
  return VideoPlayerController.networkUrl(
    Uri.parse(videoUrl),
    videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
  );
}
