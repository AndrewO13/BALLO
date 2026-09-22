/// Rewrites a Supabase Storage public object URL to an on-the-fly resize URL.
///
/// List views only need a small bitmap (avatar, logo). Using
/// `/storage/v1/render/image/public/...` avoids downloading the original
/// full-resolution file. Non-Storage URLs are returned unchanged.
///
/// Requires Storage Image Transformations (Pro). [fallbackToOriginal] callers
/// should keep the original URL for [errorBuilder] retries.
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

/// Pixel size used for a [logicalSize] widget, capped for Storage transforms.
int storageImagePixelSize(double logicalSize, {double devicePixelRatio = 2}) {
  final px = (logicalSize * devicePixelRatio).round();
  if (px < 32) return 32;
  if (px > 800) return 800;
  return px;
}
