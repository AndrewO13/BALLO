import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:palette_generator/palette_generator.dart';

import '../widgets/media_placeholders.dart';
import 'storage_image_url.dart';

final _colorCache = <String, Color>{};
final Dio _imageDio = Dio(
  BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    responseType: ResponseType.bytes,
    validateStatus: (status) => status != null && status < 500,
  ),
);

/// Returns the most prevalent color from [imagePath], with in-memory caching.
Future<Color?> dominantColorForImagePath(String? imagePath) async {
  final path = _normalizeImagePath(imagePath);
  if (path == null) return null;

  final cached = _colorCache[path];
  if (cached != null) return cached;

  try {
    final bytes = await _loadImageBytes(path);
    if (bytes == null || bytes.isEmpty) return null;

    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: 64,
      targetHeight: 64,
    );
    final frame = await codec.getNextFrame();
    final image = frame.image;
    try {
      final palette = await PaletteGenerator.fromImage(
        image,
        maximumColorCount: 16,
      );
      final color = _pickBestPaletteColor(palette);
      if (color != null) {
        _colorCache[path] = color;
      }
      return color;
    } finally {
      image.dispose();
    }
  } catch (_) {
    return null;
  }
}

Color? _pickBestPaletteColor(PaletteGenerator palette) {
  final candidates = <Color>[
    if (palette.vibrantColor != null) palette.vibrantColor!.color,
    if (palette.darkVibrantColor != null) palette.darkVibrantColor!.color,
    if (palette.lightVibrantColor != null) palette.lightVibrantColor!.color,
    if (palette.dominantColor != null) palette.dominantColor!.color,
    if (palette.mutedColor != null) palette.mutedColor!.color,
    if (palette.darkMutedColor != null) palette.darkMutedColor!.color,
    if (palette.lightMutedColor != null) palette.lightMutedColor!.color,
  ];

  for (final color in candidates) {
    if (_isUsefulCardColor(color)) return color;
  }
  return candidates.isEmpty ? null : candidates.first;
}

bool _isUsefulCardColor(Color color) {
  final hsl = HSLColor.fromColor(color);
  if (hsl.lightness > 0.93 || hsl.lightness < 0.07) return false;
  if (hsl.saturation < 0.12) return false;
  return true;
}

String? _normalizeImagePath(String? raw) {
  final trimmed = raw?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return trimmed;
  }
  if (isBundledAssetPath(trimmed)) return trimmed;
  return resolveTeamLogoPath(trimmed) ?? resolvePlayerImagePath(trimmed);
}

Future<Uint8List?> _loadImageBytes(String path) async {
  if (isBundledAssetPath(path)) {
    try {
      final data = await rootBundle.load(path);
      return data.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  for (final url in _candidateFetchUrls(path)) {
    try {
      final response = await _imageDio.get<List<int>>(url);
      final data = response.data;
      if (response.statusCode == 200 && data != null && data.isNotEmpty) {
        return Uint8List.fromList(data);
      }
    } catch (_) {
      // Try the next URL variant.
    }
  }
  return null;
}

Iterable<String> _candidateFetchUrls(String url) sync* {
  yield url;

  final uri = Uri.tryParse(url);
  if (uri == null) return;

  if (uri.query.isNotEmpty) {
    yield uri.replace(queryParameters: {}).toString();
  }

  const renderMarker = '/storage/v1/render/image/public/';
  const objectMarker = '/storage/v1/object/public/';
  if (url.contains(renderMarker)) {
    final objectUrl = url.replaceFirst(renderMarker, objectMarker).split('?').first;
    if (objectUrl != url) yield objectUrl;
  } else if (url.contains(objectMarker)) {
    final px = storageImagePixelSize(64);
    yield resizedStorageImageUrl(url, width: px, height: px);
  }
}

/// Primary text/icon color that contrasts with a [background] fill.
Color onDominantCardColor(Color background) {
  return background.computeLuminance() > 0.45
      ? const Color(0xDE000000)
      : Colors.white;
}

/// Secondary text/icon color that contrasts with a [background] fill.
Color onDominantCardMutedColor(Color background) {
  return background.computeLuminance() > 0.45
      ? const Color(0x99000000)
      : Colors.white70;
}

/// Star icon color for list cards tinted with a dominant image color.
Color dominantCardStarColor({
  required Color background,
  required ColorScheme colorScheme,
  required bool isStarred,
}) {
  if (!isStarred) {
    return onDominantCardColor(background);
  }
  return background.computeLuminance() > 0.45
      ? colorScheme.primary
      : Colors.amber;
}
