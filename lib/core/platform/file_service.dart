import 'dart:typed_data';

import 'package:meta/meta.dart';

@immutable
class PickedFile {
  const PickedFile({required this.name, required this.bytes});
  final String name;
  final Uint8List bytes;
}

/// Pick and save files on every platform (share sheet on mobile, download on web).
abstract interface class FileService {
  Future<PickedFile?> pick({List<String> extensions = const []});

  /// Returns false if the user cancelled.
  Future<bool> save(String fileName, Uint8List bytes, {required String mimeType});
}
