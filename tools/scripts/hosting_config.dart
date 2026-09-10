// Keeps firebase.json in sync with assets/brands (A7 / TECHNICAL_STRUCTURE §13).
//
//   dart run tools/scripts/hosting_config.dart ensure <brandId>
//   dart run tools/scripts/hosting_config.dart project <alias>
//   dart run tools/scripts/hosting_config.dart site <brandId> --project shelfwise-dev
//   dart run tools/scripts/hosting_config.dart brands [--json]
//
// `ensure` adds a hosting target for the brand (public dist/<brandId>, SPA rewrite,
// wasm content type, cache headers) if firebase.json does not have one yet.
// `site` prints the Hosting site that .firebaserc maps the brand's target to in the
// given project, or nothing when the target has not been applied yet.
// `brands` lists the brand ids under assets/brands (used by the release workflow).
//
// Called by tools/scripts/deploy_brand.sh; safe to run by hand and idempotent.
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

const _usage = '''
Usage:
  dart run tools/scripts/hosting_config.dart ensure <brandId> [--public <dir>]
  dart run tools/scripts/hosting_config.dart project <alias>
  dart run tools/scripts/hosting_config.dart site <brandId> --project <projectId>
  dart run tools/scripts/hosting_config.dart brands [--json]
''';

void main(List<String> args) {
  if (args.isEmpty) _fail(_usage);
  final rest = args.sublist(1);
  switch (args.first) {
    case 'ensure':
      _ensure(rest);
    case 'project':
      _project(rest);
    case 'site':
      _site(rest);
    case 'brands':
      _brands(rest);
    case '-h' || '--help':
      print(_usage);
    default:
      _fail('unknown command "${args.first}"\n$_usage');
  }
}

Never _fail(String message) {
  stderr.writeln(message.startsWith('Usage') ? message : 'ERROR  $message');
  exit(1);
}

String _option(List<String> args, String name, {String? fallback}) {
  final i = args.indexOf('--$name');
  if (i >= 0 && i + 1 < args.length) return args[i + 1];
  final prefixed = args.firstWhere((a) => a.startsWith('--$name='), orElse: () => '');
  if (prefixed.isNotEmpty) return prefixed.substring(name.length + 3);
  if (fallback != null) return fallback;
  _fail('--$name is required\n$_usage');
}

String _positional(List<String> args, String what) {
  final value = args.firstWhere((a) => !a.startsWith('-'), orElse: () => '');
  if (value.isEmpty) _fail('missing <$what>\n$_usage');
  return value;
}

// ---------------------------------------------------------------------------

void _ensure(List<String> args) {
  final brandId = _positional(args, 'brandId');
  final public = _option(args, 'public', fallback: 'dist/$brandId');

  final file = File('firebase.json');
  if (!file.existsSync()) _fail('firebase.json not found (run from the repo root)');
  final json = (jsonDecode(file.readAsStringSync()) as Map).cast<String, Object?>();

  final hosting = switch (json['hosting']) {
    final List<Object?> list => list.toList(),
    final Map<String, Object?> single => <Object?>[single],
    _ => <Object?>[],
  };

  final existing = hosting
      .whereType<Map<String, Object?>>()
      .where((e) => e['target'] == brandId)
      .firstOrNull;
  if (existing != null) {
    print('firebase.json already has a hosting target "$brandId" (${existing['public']})');
    return;
  }

  hosting.add(hostingEntry(target: brandId, public: public));
  json['hosting'] = hosting;
  file.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(json)}\n');
  print('firebase.json: added hosting target "$brandId" -> $public');
}

/// One brand's Hosting config: SPA rewrite, wasm content type, cache headers.
Map<String, Object?> hostingEntry({required String target, required String public}) => {
  'target': target,
  'public': public,
  'ignore': ['firebase.json', '**/.*'],
  'rewrites': [
    {'source': '**', 'destination': '/index.html'},
  ],
  'headers': [
    {
      'source': '**/*.wasm',
      'headers': [
        {'key': 'Content-Type', 'value': 'application/wasm'},
      ],
    },
    {
      'source': '**/*.@(js|wasm|png|ttf|otf)',
      'headers': [
        {'key': 'Cache-Control', 'value': 'max-age=604800'},
      ],
    },
    // Listed after the long-cache rule so it wins: these three decide when a
    // client picks up a new build.
    {
      'source': '/@(index.html|manifest.json|flutter_service_worker.js|version.json)',
      'headers': [
        {'key': 'Cache-Control', 'value': 'no-cache'},
      ],
    },
  ],
};

// ---------------------------------------------------------------------------

/// Resolves a `.firebaserc` project alias (dev/prod/default) to its project id.
void _project(List<String> args) {
  final alias = _positional(args, 'alias');
  final file = File('.firebaserc');
  if (!file.existsSync()) _fail('.firebaserc not found (run from the repo root)');
  final json = (jsonDecode(file.readAsStringSync()) as Map).cast<String, Object?>();
  final projects = json['projects'];
  final id = projects is Map ? projects[alias] : null;
  if (id is! String || id.isEmpty) {
    _fail('.firebaserc has no project alias "$alias"');
  }
  print(id);
}

void _site(List<String> args) {
  final brandId = _positional(args, 'brandId');
  final project = _option(args, 'project');

  final file = File('.firebaserc');
  if (!file.existsSync()) return;
  final json = (jsonDecode(file.readAsStringSync()) as Map).cast<String, Object?>();
  final targets = json['targets'];
  if (targets is! Map) return;
  final forProject = targets[project];
  if (forProject is! Map) return;
  final hosting = forProject['hosting'];
  if (hosting is! Map) return;
  final sites = hosting[brandId];
  if (sites is List && sites.isNotEmpty) print(sites.first);
}

// ---------------------------------------------------------------------------

void _brands(List<String> args) {
  final dir = Directory('assets/brands');
  if (!dir.existsSync()) _fail('assets/brands not found (run from the repo root)');
  final ids =
      dir
          .listSync()
          .whereType<Directory>()
          .map((d) => d.path.split(Platform.pathSeparator).last)
          .where((id) => File('assets/brands/$id/brand.json').existsSync())
          .toList()
        ..sort();
  print(args.contains('--json') ? jsonEncode(ids) : ids.join('\n'));
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
