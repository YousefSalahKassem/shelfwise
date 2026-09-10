import 'dart:typed_data';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:shelfwise/core/brand/brand_config.dart';
import 'package:shelfwise/core/brand/tier.dart';

/// A logo or icon the user picked, kept in memory until export.
@immutable
class BrandImage {
  const BrandImage({
    required this.bytes,
    required this.width,
    required this.height,
    required this.fileName,
  });

  final Uint8List bytes;
  final int width;
  final int height;
  final String fileName;

  bool get isSquare => (width - height).abs() <= (width * 0.02);

  /// Decodes [bytes]; returns null when they are not a readable image.
  static BrandImage? decode(Uint8List bytes, String fileName) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    return BrandImage(
      bytes: bytes,
      width: decoded.width,
      height: decoded.height,
      fileName: fileName,
    );
  }
}

/// The brand being edited. Plain mutable data — [StudioController] owns it and
/// notifies listeners. [toJson] is exactly what lands in
/// `assets/brands/<id>/brand.json`, so [BrandConfig.fromJson] can validate it.
class BrandDraft {
  BrandDraft({
    this.id = '',
    this.appName = '',
    this.tier = Tier.shelf,
    this.primary = const Color(0xFF0D6A56),
    this.secondary = const Color(0xFFA86F00),
    this.defaultLocale = 'ar',
    Set<String>? supportedLocales,
    this.defaultCurrency = 'EGP',
    this.latinDigitsByDefault = true,
    this.phone = '',
    this.whatsapp = '',
    this.email = '',
    this.companyName = '',
    this.privacyUrl = '',
    this.logo,
    this.logoDark,
    this.icon,
  }) : supportedLocales = supportedLocales ?? {'ar', 'en'};

  String id;
  String appName;
  Tier tier;
  Color primary;
  Color secondary;
  String defaultLocale;
  Set<String> supportedLocales;
  String defaultCurrency;
  bool latinDigitsByDefault;
  String phone;
  String whatsapp;
  String email;
  String companyName;
  String privacyUrl;
  BrandImage? logo;
  BrandImage? logoDark;
  BrandImage? icon;

  /// What a new brand starts from: a plausible example the team can edit.
  factory BrandDraft.starter() => BrandDraft(
    id: 'acme',
    appName: 'Acme Stock',
    companyName: 'Acme Trading',
  );

  BrandDraft copy() => BrandDraft(
    id: id,
    appName: appName,
    tier: tier,
    primary: primary,
    secondary: secondary,
    defaultLocale: defaultLocale,
    supportedLocales: {...supportedLocales},
    defaultCurrency: defaultCurrency,
    latinDigitsByDefault: latinDigitsByDefault,
    phone: phone,
    whatsapp: whatsapp,
    email: email,
    companyName: companyName,
    privacyUrl: privacyUrl,
    logo: logo,
    logoDark: logoDark,
    icon: icon,
  );

  String get folder => 'assets/brands/${id.isEmpty ? 'brand' : id}';

  /// The light logo, used wherever a dark-mode logo or icon was not provided.
  BrandImage? get effectiveLogoDark => logoDark ?? logo;
  BrandImage? get effectiveIcon => icon ?? logo;

  // -------------------------------------------------------------------------
  // brand.json
  // -------------------------------------------------------------------------

  Map<String, Object?> toJson() => {
    'id': id,
    'appName': appName,
    'tier': tier.name,
    'colors': {'primary': hex(primary), 'secondary': hex(secondary)},
    'logo': '$folder/logo.png',
    if (logoDark != null) 'logoDark': '$folder/logo_dark.png',
    if (icon != null) 'icon': '$folder/icon.png',
    'defaultLocale': defaultLocale,
    'supportedLocales': sortedLocales,
    'defaultCurrency': defaultCurrency,
    'latinDigitsByDefault': latinDigitsByDefault,
    'featureOverrides': const <String, bool>{},
    'support': {
      if (phone.trim().isNotEmpty) 'phone': phone.trim(),
      if (whatsapp.trim().isNotEmpty) 'whatsapp': whatsapp.trim(),
      if (email.trim().isNotEmpty) 'email': email.trim(),
    },
    'legal': {
      if (companyName.trim().isNotEmpty) 'companyName': companyName.trim(),
      if (privacyUrl.trim().isNotEmpty) 'privacyUrl': privacyUrl.trim(),
    },
  };

  /// `supportedLocales` with the default first — the app falls back in order.
  List<String> get sortedLocales {
    final rest = supportedLocales.where((l) => l != defaultLocale).toList()..sort();
    return [if (supportedLocales.contains(defaultLocale)) defaultLocale, ...rest];
  }

  /// Reads a `brand.json` map. Images come from the zip, so they are passed in.
  static BrandDraft fromJson(
    Map<String, Object?> json, {
    BrandImage? logo,
    BrandImage? logoDark,
    BrandImage? icon,
  }) {
    String str(String key) => json[key] is String ? (json[key]! as String).trim() : '';
    final colors = json['colors'];
    final colorMap = colors is Map ? colors : const {};
    Color color(String key, Color fallback) {
      final v = colorMap[key];
      return v is String ? (tryParseHexColor(v) ?? fallback) : fallback;
    }

    final support = json['support'];
    final supportMap = support is Map ? support : const {};
    final legal = json['legal'];
    final legalMap = legal is Map ? legal : const {};
    final rawLocales = json['supportedLocales'];
    final locales = rawLocales is List ? rawLocales.whereType<String>().toSet() : <String>{};

    return BrandDraft(
      id: str('id'),
      appName: str('appName'),
      tier: Tier.tryParse(str('tier')) ?? Tier.shelf,
      primary: color('primary', const Color(0xFF0D6A56)),
      secondary: color('secondary', const Color(0xFFA86F00)),
      defaultLocale: str('defaultLocale').isEmpty ? 'ar' : str('defaultLocale'),
      supportedLocales: locales.isEmpty ? {'ar', 'en'} : locales,
      defaultCurrency: str('defaultCurrency').isEmpty ? 'EGP' : str('defaultCurrency'),
      latinDigitsByDefault: json['latinDigitsByDefault'] as bool? ?? true,
      phone: supportMap['phone'] as String? ?? '',
      whatsapp: supportMap['whatsapp'] as String? ?? '',
      email: supportMap['email'] as String? ?? '',
      companyName: legalMap['companyName'] as String? ?? '',
      privacyUrl: legalMap['privacyUrl'] as String? ?? '',
      logo: logo,
      logoDark: logoDark,
      icon: icon,
    );
  }

  // -------------------------------------------------------------------------
  // validation
  // -------------------------------------------------------------------------

  /// The config the app would load, or null while [issues] is not empty.
  BrandConfig? toConfig() {
    try {
      return BrandConfig.fromJson(toJson());
    } on BrandConfigException {
      return null;
    }
  }

  /// Everything that stops this brand from shipping: the app's own validation
  /// (identical to what `BrandLoader` runs at startup) plus the assets, which
  /// brand.json can only reference by path.
  List<String> get issues {
    final all = <String>[];
    try {
      BrandConfig.fromJson(toJson());
    } on BrandConfigException catch (e) {
      all.addAll(e.issues);
    }
    if (logo == null) all.add('Upload a logo (light) — PNG with a transparent background');
    return all;
  }

  /// Things worth fixing that do not block a build.
  List<String> get warnings {
    final all = <String>[];
    final l = logo;
    if (l != null && (l.width < 512 || l.height < 512)) {
      all.add('The logo is ${l.width}×${l.height}; 512×512 or larger stays sharp.');
    }
    final i = icon;
    if (i == null) {
      all.add('No app icon: the light logo will be used for the home-screen icon.');
    } else if (i.width < 1024 || i.height < 1024) {
      all.add('The app icon is ${i.width}×${i.height}; 1024×1024 gives the sharpest install.');
    } else if (!i.isSquare) {
      all.add('The app icon is not square, so launchers will crop it.');
    }
    if (logoDark == null) {
      all.add('No dark-mode logo: the light logo will be used in dark mode.');
    }
    return all;
  }
}

String hex(Color color) {
  final argb = color.toARGB32();
  return '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

/// Holds the draft being edited and notifies the UI on every change.
class StudioController extends ChangeNotifier {
  StudioController([BrandDraft? draft]) : _draft = draft ?? BrandDraft.starter();

  BrandDraft _draft;
  BrandDraft get draft => _draft;

  void edit(void Function(BrandDraft draft) change) {
    change(_draft);
    notifyListeners();
  }

  void replace(BrandDraft draft) {
    _draft = draft;
    notifyListeners();
  }
}
