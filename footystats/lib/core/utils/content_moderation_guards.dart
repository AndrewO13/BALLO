import 'dart:typed_data';

import '../../data/services/content_moderation_service.dart';

/// Throws [StateError] with a user-facing message when content is rejected.
///
/// [softFailOnAuthError] (default true for text) lets onboarding continue when
/// the moderation Edge Function is briefly unauthorized/unavailable — local
/// [UsernameRules] checks still apply at the call site.
Future<ModerationResult> requireAllowedText(
  String text, {
  String? contentRef,
  ContentModerationService? service,
  bool softFailOnAuthError = true,
}) async {
  final local = text.trim();
  if (local.isEmpty) {
    throw StateError('Enter some text');
  }
  final moderation =
      await (service ?? ContentModerationService()).moderateText(
    local,
    contentRef: contentRef,
    softFailOnAuthError: softFailOnAuthError,
  );
  if (moderation.isRejected) {
    throw StateError(moderation.userMessage);
  }
  return moderation;
}

Future<ModerationResult> requireAllowedImage(
  Uint8List bytes, {
  String? contentRef,
  ContentModerationService? service,
}) async {
  final moderation =
      await (service ?? ContentModerationService()).moderateImageBytes(
    bytes,
    contentRef: contentRef,
  );
  if (moderation.isRejected) {
    throw StateError(moderation.userMessage);
  }
  return moderation;
}
