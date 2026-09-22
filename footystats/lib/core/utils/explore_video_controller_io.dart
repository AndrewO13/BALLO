import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:video_player/video_player.dart';

Future<VideoPlayerController> createExploreVideoController({
  required String videoUrl,
  required String videoId,
  required BaseCacheManager cacheManager,
}) async {
  final info = await cacheManager.getFileFromCache(videoId);
  final cached = info?.file;
  if (cached != null && await cached.exists()) {
    return VideoPlayerController.file(
      cached,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
  }
  return VideoPlayerController.networkUrl(
    Uri.parse(videoUrl),
    videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
  );
}
