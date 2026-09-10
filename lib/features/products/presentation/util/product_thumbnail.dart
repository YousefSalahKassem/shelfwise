import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Longest side of a stored thumbnail, in pixels (brief: ≤ 400 px).
const int thumbnailMaxSide = 400;

/// JPEG quality of a stored thumbnail (brief: ~70%).
const int thumbnailQuality = 70;

/// Decodes any picked image and re-encodes it as a small JPEG for
/// `product_images.thumb`. Returns null when the bytes aren't a readable image.
///
/// Runs on a background isolate on native platforms; on web `compute` runs
/// inline, which is fine for a 400 px thumbnail.
Future<Uint8List?> encodeProductThumbnail(Uint8List source) =>
    compute(_encode, source);

Uint8List? _encode(Uint8List source) {
  final decoded = img.decodeImage(source);
  if (decoded == null) return null;
  final longestSide = decoded.width > decoded.height ? decoded.width : decoded.height;
  final resized = longestSide <= thumbnailMaxSide
      ? decoded
      : img.copyResize(
          decoded,
          width: decoded.width >= decoded.height ? thumbnailMaxSide : null,
          height: decoded.height > decoded.width ? thumbnailMaxSide : null,
          interpolation: img.Interpolation.average,
        );
  return img.encodeJpg(resized, quality: thumbnailQuality);
}
