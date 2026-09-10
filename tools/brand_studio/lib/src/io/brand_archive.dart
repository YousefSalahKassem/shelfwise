import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../brand_draft.dart';

/// Reading and writing the brand folder as a zip:
///
/// ```
/// assets/brands/<id>/brand.json
/// assets/brands/<id>/logo.png
/// assets/brands/<id>/logo_dark.png   (only when provided)
/// assets/brands/<id>/icon.png        (only when provided)
/// HOW-TO.txt
/// ```
///
/// Unzipping it at the repo root puts every file exactly where the app expects
/// it (TECHNICAL_STRUCTURE §7).
abstract final class BrandArchive {
  static const _encoder = JsonEncoder.withIndent('  ');

  static String brandJson(BrandDraft draft) => '${_encoder.convert(draft.toJson())}\n';

  static String fileName(BrandDraft draft) => '${draft.id.isEmpty ? 'brand' : draft.id}-brand.zip';

  static Uint8List zip(BrandDraft draft) {
    final archive = Archive();
    final folder = draft.folder;

    archive.add(ArchiveFile.string('$folder/brand.json', brandJson(draft)));
    final logo = draft.logo;
    if (logo != null) archive.add(ArchiveFile.bytes('$folder/logo.png', logo.bytes));
    final logoDark = draft.logoDark;
    if (logoDark != null) archive.add(ArchiveFile.bytes('$folder/logo_dark.png', logoDark.bytes));
    final icon = draft.icon;
    if (icon != null) archive.add(ArchiveFile.bytes('$folder/icon.png', icon.bytes));
    archive.add(ArchiveFile.string('HOW-TO.txt', _howTo(draft)));

    return ZipEncoder().encodeBytes(archive);
  }

  /// Reads a zip produced by [zip] (or a brand folder zipped by hand).
  /// Returns null when it contains no brand.json.
  static BrandDraft? readZip(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    ArchiveFile? find(String suffix) {
      for (final f in archive.files) {
        if (f.isFile && f.name.split('/').last == suffix) return f;
      }
      return null;
    }

    final jsonFile = find('brand.json');
    if (jsonFile == null) return null;

    BrandImage? image(String name) {
      final file = find(name);
      if (file == null) return null;
      return BrandImage.decode(file.readBytes() ?? Uint8List(0), name);
    }

    return readBrandJson(
      utf8.decode(jsonFile.readBytes() ?? Uint8List(0)),
      logo: image('logo.png'),
      logoDark: image('logo_dark.png'),
      icon: image('icon.png'),
    );
  }

  /// Reads a bare `brand.json` (colours and text only — no assets).
  static BrandDraft? readBrandJson(
    String source, {
    BrandImage? logo,
    BrandImage? logoDark,
    BrandImage? icon,
  }) {
    Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      return null;
    }
    if (decoded is! Map) return null;
    return BrandDraft.fromJson(
      decoded.cast<String, Object?>(),
      logo: logo,
      logoDark: logoDark,
      icon: icon,
    );
  }

  static String _howTo(BrandDraft draft) => '''
${draft.appName} — ShelfWise brand package
${'=' * 48}

1. Unzip this file at the root of the shelfwise repository:

     unzip -o ${fileName(draft)} -d /path/to/shelfwise

   It creates ${draft.folder}/

2. Build and deploy a preview:

     tools/scripts/build_brand.sh ${draft.id}
     tools/scripts/deploy_brand.sh ${draft.id} preview

3. Commit ${draft.folder}/ and the pubspec.yaml asset line the build script adds.

Full walkthrough: docs/BRAND_ONBOARDING.md
''';
}
