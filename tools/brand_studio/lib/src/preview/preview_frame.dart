import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shelfwise/core/brand/brand_config.dart';
import 'package:shelfwise/core/domain/stock_status.dart';
import 'package:shelfwise/core/l10n/l10n.dart';
import 'package:shelfwise/core/theme/app_theme.dart';
import 'package:shelfwise/core/theme/spacing.dart';
import 'package:shelfwise/core/theme/stock_colors.dart';

import '../brand_draft.dart';

/// A phone-sized window running the real app theme, the real localisations and
/// the real text direction, so what the customer sees here is what they get.
class PreviewFrame extends StatelessWidget {
  const PreviewFrame({
    super.key,
    required this.label,
    required this.brand,
    required this.brightness,
    required this.languageCode,
    required this.child,
    this.width = 300,
    this.height = 620,
  });

  final String label;
  final BrandConfig brand;
  final Brightness brightness;
  final String languageCode;
  final Widget child;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: brightness == Brightness.dark ? Colors.black : Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: 8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              size: Size(width, height),
              textScaler: TextScaler.noScaling,
              padding: EdgeInsets.zero,
              viewPadding: EdgeInsets.zero,
              viewInsets: EdgeInsets.zero,
            ),
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: buildTheme(brand, brightness),
              locale: Locale(languageCode),
              supportedLocales: brand.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: child,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}

/// The brand logo from the bytes the user just picked (no asset on disk yet).
class DraftLogo extends StatelessWidget {
  const DraftLogo({super.key, required this.draft, this.size = 32, this.dark = false});

  final BrandDraft draft;
  final double size;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final image = dark ? draft.effectiveLogoDark : draft.logo;
    if (image == null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        alignment: Alignment.center,
        child: Text(
          draft.appName.isEmpty ? '?' : draft.appName.characters.first.toUpperCase(),
          style: TextStyle(
            fontSize: size * 0.5,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
      );
    }
    return Image.memory(
      image.bytes,
      width: size,
      height: size,
      fit: BoxFit.contain,
      semanticLabel: draft.appName,
      gaplessPlayback: true,
    );
  }
}

/// Same semantics and colours as the app's StockBadge, sized for the preview.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.status});

  final StockStatus status;

  @override
  Widget build(BuildContext context) {
    final c = StockColors.of(context);
    final l10n = context.l10n;
    final (bg, fg, label) = switch (status) {
      StockStatus.ok => (c.okContainer, c.ok, l10n.common_stockOk),
      StockStatus.low => (c.lowContainer, c.low, l10n.common_stockLow),
      StockStatus.out => (c.outContainer, c.out, l10n.common_stockOut),
    };
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadii.lg)),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg)),
    );
  }
}
