// OWNER: A6.
import 'dart:typed_data';

import 'backup_info.dart';

/// A backup file the user chose, already checked but not yet restored:
/// the summary is shown first, and only a confirmed [bytes] is applied.
class BackupCandidate {
  const BackupCandidate({required this.fileName, required this.bytes, required this.info});

  final String fileName;
  final Uint8List bytes;
  final BackupInfo info;
}
