import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../config/env_config.dart';
import '../constants/app_constants.dart';

/// Outcome of the OS share sheet or clipboard fallback.
enum VideoShareOutcome { shared, copied, dismissed }

/// Share links are pointers to a `videos.id`, not copies of the file.
class VideoShare {
  VideoShare._();

  static final _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static String get publicOrigin {
    final raw = EnvConfig.publicSiteUrl.trim();
    if (raw.isEmpty) return AppConstants.publicSiteUrl;
    return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
  }

  /// Public app URL. A versioned query busts WhatsApp's cached scrape of the
  /// old "A new Flutter project." preview.
  static Uri uriFor(String videoId) {
    return Uri.parse('$publicOrigin/').replace(
      queryParameters: {'v': videoId, 'pv': '2'},
    );
  }

  static String? incomingVideoId([Uri? uri]) {
    final resolved = uri ?? Uri.base;
    final fromQuery =
        resolved.queryParameters['v'] ?? resolved.queryParameters['video'];
    if (_isVideoId(fromQuery)) return fromQuery;

    final pathId = _idFromSegments(resolved.pathSegments);
    if (pathId != null) return pathId;

    final fragment = resolved.fragment;
    if (fragment.isEmpty) return null;
    final normalized = fragment.startsWith('/') ? fragment : '/$fragment';
    final fragUri = Uri.parse('https://share.local$normalized');
    final fromFragQuery =
        fragUri.queryParameters['v'] ?? fragUri.queryParameters['video'];
    if (_isVideoId(fromFragQuery)) return fromFragQuery;
    return _idFromSegments(fragUri.pathSegments);
  }

  static bool _isVideoId(String? value) {
    final id = value?.trim();
    return id != null && _uuidPattern.hasMatch(id);
  }

  static String? _idFromSegments(List<String> segments) {
    final parts = segments.where((s) => s.isNotEmpty).toList();
    if (parts.length >= 2 && parts.first == 'v') {
      final id = parts[1].trim();
      if (_isVideoId(id)) return id;
    }
    return null;
  }

  static Future<XFile?> _previewFile(String thumbnailUrl) async {
    try {
      final response = await Dio().get<List<int>>(
        thumbnailUrl,
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) return null;
      return XFile.fromData(
        Uint8List.fromList(bytes),
        mimeType: 'image/jpeg',
        name: 'highlight.jpg',
      );
    } catch (_) {
      return null;
    }
  }

  static Future<VideoShareOutcome> share({
    required String videoId,
    String? matchLabel,
    String? thumbnailUrl,
  }) async {
    final uri = uriFor(videoId);
    final headline = (matchLabel != null && matchLabel.trim().isNotEmpty)
        ? '${matchLabel.trim()} — highlight on Ballo'
        : 'Watch this highlight on Ballo';
    final text = '$headline\n$uri';

    XFile? preview;
    final thumb = thumbnailUrl?.trim();
    if (!kIsWeb && thumb != null && thumb.isNotEmpty) {
      preview = await _previewFile(thumb);
    }

    if (kIsWeb) {
      await Clipboard.setData(ClipboardData(text: uri.toString()));
      try {
        await SharePlus.instance.share(
          ShareParams(
            text: text,
            title: headline,
            subject: AppConstants.shareDescription,
          ),
        );
      } catch (_) {}
      return VideoShareOutcome.copied;
    }

    try {
      final result = await SharePlus.instance.share(
        ShareParams(
          text: text,
          title: headline,
          subject: AppConstants.shareDescription,
          previewThumbnail: preview,
        ),
      );
      switch (result.status) {
        case ShareResultStatus.dismissed:
          return VideoShareOutcome.dismissed;
        case ShareResultStatus.unavailable:
          await Clipboard.setData(ClipboardData(text: uri.toString()));
          return VideoShareOutcome.copied;
        case ShareResultStatus.success:
          return VideoShareOutcome.shared;
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: uri.toString()));
      return VideoShareOutcome.copied;
    }
  }
}
