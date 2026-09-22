import 'dart:typed_data';

Future<({String path, Uint8List bytes, bool didCompress})> prepareVideoForUpload({
  required String path,
  required Uint8List originalBytes,
}) async {
  return (path: path, bytes: originalBytes, didCompress: false);
}
