import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/app_assets.dart';
import '../utils/storage_image_url.dart';

/// Dedicated disk cache for images.
///
/// Videos use [DefaultCacheManager] (200-object cap). Keeping images in their
/// own cache means a session of scrolling the explore feed can no longer evict
/// every logo and avatar, which would force them to re-download.
BaseCacheManager get _appImageCacheManager =>
    debugAppImageCacheManagerOverride ?? _defaultAppImageCacheManager;

final BaseCacheManager _defaultAppImageCacheManager = CacheManager(
  Config(
    'balloImageCache',
    stalePeriod: const Duration(days: 30),
    maxNrOfCacheObjects: 1000,
  ),
);

/// Lets widget tests substitute the disk cache (which needs native plugins).
@visibleForTesting
BaseCacheManager? debugAppImageCacheManagerOverride;

/// Disk-cached provider for any network image (logos, avatars, banners,
/// thumbnails). Use this instead of [NetworkImage] so images are downloaded
/// once and reused across rebuilds, navigation and app restarts.
///
/// When [width] is given the image is downsampled on the client to roughly
/// [width]x[height] (aspect ratio preserved) so list avatars/logos do not keep
/// the full-resolution upload decoded in memory. The original file is still
/// what gets downloaded and cached, so one download serves every size.
ImageProvider<Object> appCachedImageProvider(
  String url, {
  int? width,
  int? height,
}) {
  final trimmed = url.trim();
  final resolved = (kStorageImageTransformsEnabled && width != null)
      ? resizedStorageImageUrl(trimmed, width: width, height: height)
      : trimmed;

  // On web, CachedNetworkImage's default HtmlImage codec is uploaded to
  // WebGL and fails with a cross-origin texImage2D error. NetworkImage
  // fetches bytes with CORS (Storage already sends Access-Control-Allow-Origin: *).
  final ImageProvider<Object> provider = kIsWeb
      ? NetworkImage(resolved)
      : CachedNetworkImageProvider(
          resolved,
          cacheManager: _appImageCacheManager,
          errorListener: kDebugMode
              ? (error) =>
                    debugPrint('[appCachedImageProvider] $resolved -> $error')
              : null,
        );

  if (width == null || kIsWeb) return provider;
  return ResizeImage(
    provider,
    width: width,
    height: height ?? width,
    policy: ResizeImagePolicy.fit,
  );
}

/// True only for bundled asset paths declared in [pubspec.yaml].
bool isBundledAssetPath(String path) {
  final value = path.trim();
  return value.startsWith('lib/assets/') || value.startsWith('assets/');
}

/// Resolves [logoId] from the database to a displayable image path.
///
/// Supports full URLs, bundled asset paths, and Supabase Storage keys under
/// the `Profile images` bucket (including legacy bare filenames like
/// `Lefters.png`).
String? resolveTeamLogoPath(String? logoId) {
  final id = logoId?.trim();
  if (id == null || id.isEmpty) return null;
  if (id.startsWith('http://') || id.startsWith('https://')) return id;
  if (isBundledAssetPath(id)) return id;

  try {
    final storage = Supabase.instance.client.storage.from('Profile images');
    if (id.contains('/')) {
      return storage.getPublicUrl(id);
    }
    final name = id.contains('.') ? id : '$id.png';
    return storage.getPublicUrl('team logos/$name');
  } catch (_) {
    return null;
  }
}

/// Matches [ThemeData.scaffoldBackgroundColor] used on [HomePage].
Widget onboardingBackdrop(BuildContext context) {
  return ColoredBox(
    color: Theme.of(context).scaffoldBackgroundColor,
  );
}

Widget teamLogoPlaceholder({required double size, Color? iconColor}) {
  return Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: const BoxDecoration(shape: BoxShape.circle),
    child: Icon(
      Icons.shield_outlined,
      size: size * 0.55,
      color: iconColor,
    ),
  );
}

Widget buildTeamLogo(
  String? path, {
  double size = 24,
  BoxFit fit = BoxFit.cover,
  Color? placeholderIconColor,
}) {
  final resolved = path?.trim();
  if (resolved == null || resolved.isEmpty) {
    return teamLogoPlaceholder(size: size, iconColor: placeholderIconColor);
  }
  if (resolved.startsWith('http://') || resolved.startsWith('https://')) {
    final px = storageImagePixelSize(size);
    return Image(
      image: appCachedImageProvider(resolved, width: px, height: px),
      width: size,
      height: size,
      fit: fit,
      errorBuilder: (_, _, _) => Image(
        image: appCachedImageProvider(resolved),
        width: size,
        height: size,
        fit: fit,
        errorBuilder: (_, _, _) =>
            teamLogoPlaceholder(size: size, iconColor: placeholderIconColor),
      ),
    );
  }
  if (isBundledAssetPath(resolved)) {
    return Image.asset(
      resolved,
      width: size,
      height: size,
      fit: fit,
      errorBuilder: (_, _, _) =>
          teamLogoPlaceholder(size: size, iconColor: placeholderIconColor),
    );
  }
  return teamLogoPlaceholder(size: size, iconColor: placeholderIconColor);
}

Widget playerAvatarPlaceholder({
  required double size,
  Color? backgroundColor,
  Color? iconColor,
}) {
  return Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: backgroundColor,
      shape: BoxShape.circle,
    ),
    child: Icon(
      Icons.person,
      size: size * 0.55,
      color: iconColor,
    ),
  );
}

/// Player image from network URL, avatar asset path, or bundled avatar filename.
String? resolvePlayerImagePath(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) return null;
  if (value.startsWith('http://') || value.startsWith('https://')) {
    return value;
  }
  if (value.startsWith('lib/assets/') || value.startsWith('assets/')) {
    return value;
  }
  if (value.contains('avatar') || value.startsWith('3d_avatar')) {
    final name = value.contains('.') ? value : '$value.png';
    return '${AppAssets.avatarsPath}$name';
  }
  return null;
}

/// Full-resolution network provider for profile photo lightbox (separate cache key
/// from the avatar thumbnail so the expanded view is not blurry).
ImageProvider<Object> playerProfileFullImageProvider(String url) {
  return appCachedImageProvider(url);
}

Widget buildPlayerProfileFullImage({
  required String imagePath,
  BoxFit fit = BoxFit.contain,
}) {
  final isNetwork =
      imagePath.startsWith('http://') || imagePath.startsWith('https://');
  if (isNetwork) {
    return Image(
      image: playerProfileFullImageProvider(imagePath),
      fit: fit,
      filterQuality: FilterQuality.high,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined),
    );
  }
  return Image.asset(
    imagePath,
    fit: fit,
    filterQuality: FilterQuality.high,
    errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined),
  );
}

Widget buildPlayerAvatar({
  String? imagePath,
  double size = 48,
  Color? backgroundColor,
  Color? iconColor,
}) {
  final resolved = resolvePlayerImagePath(imagePath);
  if (resolved == null || resolved.isEmpty) {
    return playerAvatarPlaceholder(
      size: size,
      backgroundColor: backgroundColor,
      iconColor: iconColor,
    );
  }
  final isNetwork =
      resolved.startsWith('http://') || resolved.startsWith('https://');
  return ClipOval(
    child: SizedBox(
      width: size,
      height: size,
      child: isNetwork
          ? Image(
              image: appCachedImageProvider(
                resolved,
                width: storageImagePixelSize(size),
                height: storageImagePixelSize(size),
              ),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Image(
                image: appCachedImageProvider(resolved),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => playerAvatarPlaceholder(
                  size: size,
                  backgroundColor: backgroundColor,
                  iconColor: iconColor,
                ),
              ),
            )
          : Image.asset(
              resolved,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => playerAvatarPlaceholder(
                size: size,
                backgroundColor: backgroundColor,
                iconColor: iconColor,
              ),
            ),
    ),
  );
}

Widget videoThumbnailPlaceholder(
  BuildContext context, {
  double iconSize = 48,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  return ColoredBox(
    color: colorScheme.surfaceContainerHighest,
    child: Center(
      child: Icon(
        Icons.play_circle_outline,
        size: iconSize,
        color: colorScheme.onSurfaceVariant,
      ),
    ),
  );
}
