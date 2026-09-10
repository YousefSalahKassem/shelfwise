import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Hands [bytes] to the browser as a download.
Future<void> downloadBytes(
  Uint8List bytes,
  String fileName, {
  String mimeType = 'application/octet-stream',
}) async {
  final blob = web.Blob(
    <JSUint8Array>[bytes.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = fileName
    ..style.display = 'none';
  web.document.body!.appendChild(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}
