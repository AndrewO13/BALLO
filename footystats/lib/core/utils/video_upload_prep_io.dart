import 'dart:io';
import 'dart:typed_data';

import 'package:video_compress/video_compress.dart';

Future<({String path, Uint8List bytes, bool didCompress})> prepareVideoForUpload({
  required String path,
  required Uint8List originalBytes,
}) async {
  if (!(Platform.isAndroid || Platform.isIOS)) {
    return (path: path, bytes: originalBytes, didCompress: false);
  }
  if (path.isEmpty) {
    return (path: path, bytes: originalBytes, didCompress: false);
  }

  try {
    final info = await VideoCompress.compressVideo(
      path,
      quality: VideoQuality.MediumQuality,
      deleteOrigin: false,
      includeAudio: true,
    );
    final compressedPath = info?.path;
    if (compressedPath == null || compressedPath.isEmpty) {
      return (path: path, bytes: originalBytes, didCompress: false);
    }
    final compressedBytes = await File(compressedPath).readAsBytes();
    if (compressedBytes.isEmpty ||
        compressedBytes.length >= originalBytes.length) {
      return (path: path, bytes: originalBytes, didCompress: false);
    }
    return (
      path: compressedPath,
      bytes: compressedBytes,
      didCompress: true,
    );
  } catch (_) {
    return (path: path, bytes: originalBytes, didCompress: false);
  }
}
