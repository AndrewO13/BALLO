import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Single shared disk cache for match/explore videos.
///
/// Sharing one [BaseCacheManager] between the explore feed, the continuous
/// video player and the fixture video player means a clip downloaded once is
/// reused everywhere instead of being re-streamed per screen.
class AppVideoCache {
  AppVideoCache._();

  static final AppVideoCache instance = AppVideoCache._();

  final BaseCacheManager cacheManager = DefaultCacheManager();
}
