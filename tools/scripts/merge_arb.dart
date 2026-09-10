// Merges per-feature ARB fragments into lib/core/l10n/arb/app_{en,ar}.arb.
//
//   dart run tools/scripts/merge_arb.dart
//
// Sources:
//   lib/core/l10n/common_<locale>.arb            → prefix common_
//   lib/features/<feature>/l10n/*_<locale>.arb   → prefix per feature (below)
//   lib/core/**/impl/l10n/*_<locale>.arb         → prefix = file stem (e.g. platform_)
// Fails (exit 1) on: duplicate keys, a key missing in another locale,
// a key with the wrong prefix, or invalid JSON.
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

const locales = ['en', 'ar'];
const featurePrefixes = {
  'categories': 'catalogue_',
  'products': 'catalogue_',
  'import_export': 'import_',
};

void main() {
  final errors = <String>[];
  final merged = {for (final l in locales) l: <String, Object?>{'@@locale': l}};
  final owner = <String, String>{};
  final keysByLocale = {for (final l in locales) l: <String>{}};

  void addFile(File file, String locale, String prefix) {
    Map<String, Object?> json;
    try {
      json = (jsonDecode(file.readAsStringSync()) as Map).cast<String, Object?>();
    } on Object catch (e) {
      errors.add('${file.path}: invalid JSON ($e)');
      return;
    }
    json.forEach((key, value) {
      if (key == '@@locale') return;
      final bare = key.startsWith('@') ? key.substring(1) : key;
      if (!bare.startsWith(prefix)) {
        errors.add('${file.path}: "$key" must start with "$prefix"');
        return;
      }
      final id = '$locale:$key';
      if (owner.containsKey(id)) {
        errors.add('${file.path}: duplicate key "$key" (also in ${owner[id]})');
        return;
      }
      owner[id] = file.path;
      merged[locale]![key] = value;
      if (!key.startsWith('@')) keysByLocale[locale]!.add(key);
    });
  }

  String? localeOf(String path) {
    for (final l in locales) {
      if (path.endsWith('_$l.arb')) return l;
    }
    return null;
  }

  // Common
  for (final l in locales) {
    final f = File('lib/core/l10n/common_$l.arb');
    if (f.existsSync()) {
      addFile(f, l, 'common_');
    } else {
      errors.add('Missing ${f.path}');
    }
  }

  // Features
  final features = Directory('lib/features');
  if (features.existsSync()) {
    for (final dir in features.listSync().whereType<Directory>()) {
      final name = dir.uri.pathSegments.where((s) => s.isNotEmpty).last;
      final l10nDir = Directory('${dir.path}/l10n');
      if (!l10nDir.existsSync()) continue;
      final prefix = featurePrefixes[name] ?? '${name}_';
      for (final f in l10nDir.listSync().whereType<File>().where((f) => f.path.endsWith('.arb'))) {
        final l = localeOf(f.path);
        if (l == null) {
          errors.add('${f.path}: file name must end with _<locale>.arb (${locales.join(', ')})');
          continue;
        }
        addFile(f, l, prefix);
      }
    }
  }

  // Core implementation fragments (e.g. lib/core/platform/impl/l10n/platform_en.arb)
  for (final e in Directory('lib/core').listSync(recursive: true).whereType<File>()) {
    final p = e.path.replaceAll(r'\', '/');
    if (!p.contains('/impl/l10n/') || !p.endsWith('.arb')) continue;
    final l = localeOf(p);
    if (l == null) continue;
    final stem = p.split('/').last.replaceFirst('_$l.arb', '');
    addFile(e, l, '${stem}_');
  }

  // Every key must exist in every locale.
  final all = keysByLocale.values.expand((k) => k).toSet();
  for (final l in locales) {
    for (final missing in all.difference(keysByLocale[l]!)) {
      errors.add('Key "$missing" is missing in locale "$l"');
    }
  }

  if (errors.isNotEmpty) {
    stderr.writeln('merge_arb: ${errors.length} problem(s):');
    for (final e in errors) {
      stderr.writeln('  - $e');
    }
    exit(1);
  }

  final out = Directory('lib/core/l10n/arb')..createSync(recursive: true);
  const encoder = JsonEncoder.withIndent('  ');
  for (final l in locales) {
    final sorted = <String, Object?>{'@@locale': l};
    final keys = merged[l]!.keys.where((k) => k != '@@locale').toList()..sort();
    for (final k in keys) {
      sorted[k] = merged[l]![k];
    }
    File('${out.path}/app_$l.arb').writeAsStringSync('${encoder.convert(sorted)}\n');
  }
  print('merge_arb: wrote ${all.length} keys × ${locales.length} locales to ${out.path}');
}
