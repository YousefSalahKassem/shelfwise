import 'dart:typed_data';

/// Brand Studio ships as a web app; on the VM (tests) there is nothing to do.
Future<void> downloadBytes(
  Uint8List bytes,
  String fileName, {
  String mimeType = 'application/octet-stream',
}) async => throw UnsupportedError('Downloads are only available in the browser build');
