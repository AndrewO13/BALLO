/// Whether to request server-side resized images from Supabase Storage
/// (`/storage/v1/render/image/public/...`).
///
/// This is Supabase's *Image Transformations* feature, which is only available
/// on paid plans. On this project every such request is rejected with
/// `403 {"error":"FeatureNotEnabled"}`, which made every sized logo/avatar fail
/// its first load and fall back to a second request for the original file.
///
/// Keep this `false` unless the Storage "Image Transformations" add-on is
/// enabled for the project. Client-side downsampling via `ResizeImage` is used
/// regardless, so turning this on is purely a bandwidth optimisation.
const bool kStorageImageTransformsEnabled = false;

/// Rewrites a Supabase Storage public object URL to an on-the-fly resize URL.
///
/// Only used when [kStorageImageTransformsEnabled] is `true`. Non-Storage URLs
/// are returned unchanged.
String resizedStorageImageUrl(
  String url, {
  required int width,
  int? height,
  int quality = 70,
}) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return trimmed;

  const objectMarker = '/storage/v1/object/public/';
  const renderMarker = '/storage/v1/render/image/public/';

  String transformed;
  if (trimmed.contains(objectMarker)) {
    transformed = trimmed.replaceFirst(objectMarker, renderMarker);
  } else if (trimmed.contains(renderMarker)) {
    transformed = trimmed;
  } else {
    return trimmed;
  }

  final uri = Uri.tryParse(transformed);
  if (uri == null) return trimmed;

  final params = Map<String, String>.from(uri.queryParameters);
  params['width'] = width.clamp(1, 2500).toString();
  if (height != null) {
    params['height'] = height.clamp(1, 2500).toString();
  }
  params['resize'] = 'cover';
  params['quality'] = quality.clamp(20, 100).toString();
  return uri.replace(queryParameters: params).toString();
}

/// Decode/pixel size used for a [logicalSize] widget.
///
/// Uses a 3x ratio so small logos and avatars stay sharp on high-density
/// phones while still decoding far fewer pixels than the original upload.
int storageImagePixelSize(double logicalSize, {double devicePixelRatio = 3}) {
  final px = (logicalSize * devicePixelRatio).round();
  if (px < 32) return 32;
  if (px > 800) return 800;
  return px;
}
