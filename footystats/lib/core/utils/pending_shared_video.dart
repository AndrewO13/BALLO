import 'package:flutter/foundation.dart';

/// Holds a highlight id from a share link until the navigator can open it.
class PendingSharedVideo {
  PendingSharedVideo._();

  static final ValueNotifier<String?> id = ValueNotifier<String?>(null);

  static void offer(String? videoId) {
    final trimmed = videoId?.trim();
    if (trimmed == null || trimmed.isEmpty) return;
    if (id.value == trimmed) return;
    id.value = trimmed;
  }
}
