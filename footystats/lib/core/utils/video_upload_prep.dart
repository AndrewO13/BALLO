import 'dart:typed_data';

import 'video_upload_prep_stub.dart'
    if (dart.library.io) 'video_upload_prep_io.dart' as impl;

/// Result of optional transcode-before-upload.
class PreparedVideoUpload {
  const PreparedVideoUpload({
    required this.path,
    required this.bytes,
    this.didCompress = false,
  });

  final String path;
  final Uint8List bytes;
  final bool didCompress;
}

/// Compresses a gallery clip on mobile when possible so uploads stay smaller.
///
/// Web and desktop fall back to the original bytes. Compression failure also
/// falls back to the original file so upload still succeeds.
Future<PreparedVideoUpload> prepareVideoForUpload({
  required String path,
  required Uint8List originalBytes,
}) async {
  final result = await impl.prepareVideoForUpload(
    path: path,
    originalBytes: originalBytes,
  );
  return PreparedVideoUpload(
    path: result.path,
    bytes: result.bytes,
    didCompress: result.didCompress,
  );
}
