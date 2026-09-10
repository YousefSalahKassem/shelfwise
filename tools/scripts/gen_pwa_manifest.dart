// Generates the per-brand PWA files for a web build (A7 / TECHNICAL_STRUCTURE §13).
//
//   dart run tools/scripts/gen_pwa_manifest.dart <brandId> [--out build/web]
//   dart run tools/scripts/gen_pwa_manifest.dart <brandId> --validate-only
//
// Reads assets/brands/<brandId>/brand.json and writes, into --out:
//   manifest.json          name, short_name, colours, lang/dir, icon list
//   icons/Icon-{192,512}.png, icons/Icon-maskable-{192,512}.png, favicon.png
//   index.html             title, description, theme colour, splash colours, lang/dir
//
// Validation mirrors BrandConfig.fromJson (lib/core/brand/brand_config.dart), which
// cannot be imported here because it depends on dart:ui. The authoritative check is
// the test `every bundled brand.json is valid and matches its folder`
// (test/core/brand/brand_config_test.dart) — CI runs it for every brand.
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;

const _knownTiers = {'shelf', 'aisle', 'chain'};
const _knownLocales = {'ar', 'en'};
const _knownCurrencies = {'EGP', 'SAR'};
const _rtlLocales = {'ar'};

const _usage = '''
Usage: dart run tools/scripts/gen_pwa_manifest.dart <brandId> [options]

  --out <dir>          where to write (default: build/web)
  --brands-dir <dir>   where brands live (default: assets/brands)
  --validate-only      validate brand.json and exit
''';

void main(List<String> args) {
  final positional = <String>[];
  var outDir = 'build/web';
  var brandsDir = 'assets/brands';
  var validateOnly = false;

  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    String next(String flag) {
      if (i + 1 >= args.length) _fail('$flag needs a value');
      return args[++i];
    }

    switch (a) {
      case '--validate-only':
        validateOnly = true;
      case '--out':
        outDir = next(a);
      case '--brands-dir':
        brandsDir = next(a);
      case '-h' || '--help':
        print(_usage);
        exit(0);
      default:
        if (a.startsWith('--out=')) {
          outDir = a.substring('--out='.length);
        } else if (a.startsWith('--brands-dir=')) {
          brandsDir = a.substring('--brands-dir='.length);
        } else if (a.startsWith('-')) {
          _fail('unknown option "$a"\n$_usage');
        } else {
          positional.add(a);
        }
    }
  }

  if (positional.length != 1) _fail('expected exactly one <brandId>\n$_usage');
  final brandId = positional.single;

  final brand = _readBrand(brandId, brandsDir);
  print('OK  ${brand.id}: brand.json is valid (${brand.appName}, ${brand.tier})');
  if (validateOnly) return;

  final out = Directory(outDir);
  if (!out.existsSync()) {
    _fail('output directory "$outDir" does not exist - run the web build first');
  }

  _writeIcons(brand, out);
  _writeManifest(brand, out);
  _patchIndexHtml(brand, out);
  print('OK  ${brand.id}: manifest, icons and index.html written to $outDir');
}

Never _fail(String message) {
  stderr.writeln('ERROR  $message');
  exit(1);
}

// ---------------------------------------------------------------------------
// brand.json
// ---------------------------------------------------------------------------

class Brand {
  Brand({
    required this.id,
    required this.appName,
    required this.tier,
    required this.primary,
    required this.secondary,
    required this.iconPath,
    required this.defaultLocale,
    required this.description,
  });

  final String id;
  final String appName;
  final String tier;
  final int primary; // 0xAARRGGBB
  final int secondary;
  final String iconPath;
  final String defaultLocale;
  final String description;

  bool get isRtl => _rtlLocales.contains(defaultLocale);

  /// Light surface of the generated Material theme, approximated as the brand
  /// tint over white. Used for the splash and the PWA background colour.
  int get background => _blend(0xFFFFFFFF, primary, 0.04);

  int get backgroundDark => _blend(0xFF101410, primary, 0.06);
}

Brand _readBrand(String brandId, String brandsDir) {
  final file = File('$brandsDir/$brandId/brand.json');
  if (!file.existsSync()) _fail('${file.path} not found');

  Object? decoded;
  try {
    decoded = jsonDecode(file.readAsStringSync());
  } on FormatException catch (e) {
    _fail('${file.path}: invalid JSON ($e)');
  }
  if (decoded is! Map) _fail('${file.path}: must be a JSON object');
  final json = decoded.cast<String, Object?>();

  final issues = <String>[];

  String str(String key, {bool required = true}) {
    final v = json[key];
    if (v is String && v.trim().isNotEmpty) return v.trim();
    if (required) issues.add('"$key" must be a non-empty string');
    return '';
  }

  int color(String key) {
    final colors = json['colors'];
    final v = colors is Map ? colors[key] : null;
    final parsed = v is String ? _parseHexColor(v) : null;
    if (parsed == null) issues.add('"colors.$key" must be a hex colour like #0D6A56');
    return parsed ?? 0xFF000000;
  }

  final id = str('id');
  if (id.isNotEmpty && !RegExp(r'^[a-z0-9][a-z0-9-]{1,39}$').hasMatch(id)) {
    issues.add('"id" must be lowercase letters, digits and dashes (2-40 chars)');
  }
  if (id.isNotEmpty && id != brandId) {
    issues.add('"id" ($id) must match the folder name ($brandId)');
  }
  final appName = str('appName');
  final tier = str('tier');
  if (tier.isNotEmpty && !_knownTiers.contains(tier)) {
    issues.add('"tier" must be one of ${_knownTiers.join(', ')}');
  }
  if (json['colors'] is! Map) issues.add('"colors" must be an object');
  final primary = color('primary');
  final secondary = color('secondary');

  final logo = str('logo');
  final logoDark = str('logoDark', required: false);
  final icon = str('icon', required: false);
  final assets = {logo, logoDark, icon}..removeWhere((p) => p.isEmpty);
  for (final path in assets) {
    if (!File(path).existsSync()) issues.add('asset "$path" does not exist');
  }

  final supported = <String>[];
  final rawLocales = json['supportedLocales'];
  if (rawLocales is List && rawLocales.isNotEmpty) {
    for (final l in rawLocales) {
      if (l is String && _knownLocales.contains(l)) {
        supported.add(l);
      } else {
        issues.add('unsupported locale "$l" (known: ${_knownLocales.join(', ')})');
      }
    }
  } else {
    issues.add('"supportedLocales" must be a non-empty list');
  }
  final defaultLocale = str('defaultLocale');
  if (defaultLocale.isNotEmpty && !supported.contains(defaultLocale)) {
    issues.add('"defaultLocale" must be one of supportedLocales');
  }

  final currency = str('defaultCurrency');
  if (currency.isNotEmpty && !_knownCurrencies.contains(currency)) {
    issues.add('"defaultCurrency" must be one of ${_knownCurrencies.join(', ')}');
  }

  if (issues.isNotEmpty) {
    _fail('${file.path} is not a valid brand:\n  - ${issues.join('\n  - ')}');
  }

  final iconPath = icon.isNotEmpty ? icon : logo;
  final decodedIcon = img.decodeImage(File(iconPath).readAsBytesSync());
  if (decodedIcon == null) _fail('"$iconPath" is not a readable image');
  if (decodedIcon.width < 512 || decodedIcon.height < 512) {
    stderr.writeln(
      'WARN  "$iconPath" is ${decodedIcon.width}x${decodedIcon.height};'
      ' 1024x1024 gives sharper home-screen icons',
    );
  }

  final legal = json['legal'];
  final companyName = legal is Map ? legal['companyName'] as String? : null;

  return Brand(
    id: id,
    appName: appName,
    tier: tier,
    primary: primary,
    secondary: secondary,
    iconPath: iconPath,
    defaultLocale: defaultLocale,
    description: companyName == null || companyName.isEmpty
        ? '$appName - products, prices and stock for your store.'
        : '$appName by $companyName - products, prices and stock for your store.',
  );
}

// ---------------------------------------------------------------------------
// output
// ---------------------------------------------------------------------------

void _writeIcons(Brand brand, Directory out) {
  final source = img.decodeImage(File(brand.iconPath).readAsBytesSync())!;
  final icons = Directory('${out.path}/icons')..createSync(recursive: true);

  img.Image square(int size) =>
      img.copyResize(source, width: size, height: size, interpolation: img.Interpolation.cubic);

  // Maskable icons are cropped by the launcher: keep the logo inside the
  // inner 80% safe zone, on an opaque background.
  img.Image maskable(int size) {
    final canvas = img.Image(width: size, height: size, numChannels: 4);
    final bg = brand.background;
    img.fill(
      canvas,
      color: img.ColorRgba8((bg >> 16) & 0xFF, (bg >> 8) & 0xFF, bg & 0xFF, 0xFF),
    );
    final inner = (size * 0.8).round();
    final offset = ((size - inner) / 2).round();
    return img.compositeImage(
      canvas,
      img.copyResize(source, width: inner, height: inner, interpolation: img.Interpolation.cubic),
      dstX: offset,
      dstY: offset,
    );
  }

  File('${icons.path}/Icon-192.png').writeAsBytesSync(img.encodePng(square(192)));
  File('${icons.path}/Icon-512.png').writeAsBytesSync(img.encodePng(square(512)));
  File('${icons.path}/Icon-maskable-192.png').writeAsBytesSync(img.encodePng(maskable(192)));
  File('${icons.path}/Icon-maskable-512.png').writeAsBytesSync(img.encodePng(maskable(512)));
  File('${out.path}/favicon.png').writeAsBytesSync(img.encodePng(square(32)));
}

void _writeManifest(Brand brand, Directory out) {
  final manifest = <String, Object?>{
    'id': '/',
    'name': brand.appName,
    'short_name': _shortName(brand.appName),
    'description': brand.description,
    'start_url': '.',
    'scope': '.',
    'display': 'standalone',
    'orientation': 'portrait-primary',
    'lang': brand.defaultLocale,
    'dir': brand.isRtl ? 'rtl' : 'ltr',
    'background_color': _hex(brand.background),
    'theme_color': _hex(brand.primary),
    'prefer_related_applications': false,
    'icons': [
      {'src': 'icons/Icon-192.png', 'sizes': '192x192', 'type': 'image/png', 'purpose': 'any'},
      {'src': 'icons/Icon-512.png', 'sizes': '512x512', 'type': 'image/png', 'purpose': 'any'},
      {
        'src': 'icons/Icon-maskable-192.png',
        'sizes': '192x192',
        'type': 'image/png',
        'purpose': 'maskable',
      },
      {
        'src': 'icons/Icon-maskable-512.png',
        'sizes': '512x512',
        'type': 'image/png',
        'purpose': 'maskable',
      },
    ],
  };
  File(
    '${out.path}/manifest.json',
  ).writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(manifest)}\n');
}

/// Home-screen labels are truncated around 12 characters.
String _shortName(String appName) {
  if (appName.length <= 12) return appName;
  final firstWord = appName.split(RegExp(r'\s+')).first;
  return firstWord.length <= 12 ? firstWord : firstWord.substring(0, 12);
}

void _patchIndexHtml(Brand brand, Directory out) {
  final file = File('${out.path}/index.html');
  if (!file.existsSync()) _fail('${file.path} not found - run the web build first');
  var html = file.readAsStringSync();

  html = html.replaceFirst(
    RegExp('<html[^>]*>'),
    brand.isRtl
        ? '<html lang="${brand.defaultLocale}" dir="rtl">'
        : '<html lang="${brand.defaultLocale}">',
  );
  html = html.replaceFirst(
    RegExp('<title>[^<]*</title>'),
    '<title>${_escapeHtml(brand.appName)}</title>',
  );
  html = _metaAttr(html, 'description', brand.description);
  html = _metaAttr(html, 'apple-mobile-web-app-title', brand.appName);
  html = _metaAttr(html, 'theme-color', _hex(brand.primary));
  html = _cssVar(html, 'brand-primary', _hex(brand.primary));
  html = _cssVar(html, 'brand-bg', _hex(brand.background));
  html = _cssVar(html, 'brand-bg-dark', _hex(brand.backgroundDark));

  file.writeAsStringSync(html);
}

String _metaAttr(String html, String name, String value) => html.replaceAllMapped(
  RegExp('(<meta\\s+name="$name"\\s+content=")[^"]*(")'),
  (m) => '${m[1]}${_escapeHtml(value)}${m[2]}',
);

String _cssVar(String html, String name, String value) => html.replaceAllMapped(
  RegExp('(--$name:\\s*)#[0-9A-Fa-f]{3,8}'),
  (m) => '${m[1]}$value',
);

String _escapeHtml(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

// ---------------------------------------------------------------------------
// colours
// ---------------------------------------------------------------------------

int? _parseHexColor(String hex) {
  var h = hex.trim().replaceFirst('#', '');
  if (h.length == 6) h = 'FF$h';
  if (h.length != 8) return null;
  return int.tryParse(h, radix: 16);
}

String _hex(int argb) => '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// [top] over [bottom] at [amount] opacity, ignoring alpha.
int _blend(int bottom, int top, double amount) {
  int channel(int shift) {
    final b = (bottom >> shift) & 0xFF;
    final t = (top >> shift) & 0xFF;
    return (b + (t - b) * amount).round().clamp(0, 255);
  }

  return 0xFF000000 | (channel(16) << 16) | (channel(8) << 8) | channel(0);
}
