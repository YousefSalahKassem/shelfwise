// OWNER: A5. Real [FileService]: pick everywhere, save through the share sheet
// on phones, a save dialog on desktop and a download in the browser.
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

import '../../file_service.dart';

/// Phones have no visible file system to save into — the share sheet is the
/// way out (save to Files, send to WhatsApp, mail it to yourself).
bool defaultUseShareSheet() {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}

class PlatformFileService implements FileService {
  const PlatformFileService({required this.useShareSheet});

  final bool useShareSheet;

  @override
  Future<PickedFile?> pick({List<String> extensions = const []}) async {
    final file = await FilePicker.pickFile(
      type: extensions.isEmpty ? FileType.any : FileType.custom,
      allowedExtensions: extensions.isEmpty ? null : extensions,
    );
    if (file == null) return null;
    return PickedFile(name: file.name, bytes: await file.readAsBytes());
  }

  @override
  Future<bool> save(String fileName, Uint8List bytes, {required String mimeType}) async {
    if (useShareSheet) {
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, name: fileName, mimeType: mimeType)],
          fileNameOverrides: [fileName],
          subject: fileName,
        ),
      );
      return result.status != ShareResultStatus.dismissed;
    }
    final uri = await FilePicker.saveFile(
      fileName: fileName,
      bytes: bytes,
      mimeType: mimeType,
    );
    return uri != null;
  }
}
