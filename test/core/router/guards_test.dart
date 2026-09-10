import 'package:flutter_test/flutter_test.dart';
import 'package:shelfwise/core/brand/feature_flag.dart';
import 'package:shelfwise/core/brand/feature_flags.dart';
import 'package:shelfwise/core/brand/tier.dart';
import 'package:shelfwise/core/router/guards.dart';
import 'package:shelfwise/core/router/route_paths.dart';
import 'package:shelfwise/core/session/fake_session.dart';
import 'package:shelfwise/core/session/session_reader.dart';

void main() {
  const aisle = FeatureFlags(tier: Tier.aisle);

  String? go(String location, {SessionReader session = FakeSession.ownerSession, FeatureFlags flags = aisle}) =>
      redirectFor(location: location, session: session, flags: flags);

  test('no store → onboarding', () {
    expect(go(RoutePaths.dashboard, session: FakeSession.noStore), RoutePaths.onboarding);
    expect(go(RoutePaths.onboarding, session: FakeSession.noStore), isNull);
  });

  test('locked → lock screen, and lock leaves once unlocked', () {
    expect(go(RoutePaths.products, session: FakeSession.locked), RoutePaths.lock);
    expect(go(RoutePaths.lock, session: FakeSession.locked), isNull);
    expect(go(RoutePaths.lock), RoutePaths.initial);
    expect(go(RoutePaths.onboarding), RoutePaths.initial);
  });

  test('owner can reach everything', () {
    for (final p in [
      RoutePaths.pricesBulk,
      RoutePaths.priceEditFor('prod-1'),
      RoutePaths.productNew,
      RoutePaths.productEditFor('prod-1'),
      RoutePaths.settingsProfiles,
      RoutePaths.settingsBackup,
      RoutePaths.settingsImport,
    ]) {
      expect(go(p), isNull, reason: p);
    }
  });

  test('staff is blocked from owner-only routes, also by typed URL', () {
    const staff = FakeSession.staffSession;
    for (final p in [
      RoutePaths.pricesBulk,
      RoutePaths.priceEditFor('prod-1'),
      RoutePaths.productNew,
      RoutePaths.productEditFor('prod-1'),
      RoutePaths.settingsProfiles,
      RoutePaths.settingsBackup,
      RoutePaths.settingsImport,
    ]) {
      expect(go(p, session: staff), RoutePaths.initial, reason: p);
    }
    expect(go(RoutePaths.productDetailFor('prod-1'), session: staff), isNull);
    expect(go(RoutePaths.stockReceive, session: staff), isNull);
    expect(go(RoutePaths.stockAdjust, session: staff), isNull);
    expect(go('${RoutePaths.products}?q=milk', session: staff), isNull);
  });

  test('tier-gated route follows flags', () {
    const noCount = FeatureFlags(tier: Tier.shelf, overrides: {FeatureFlag.stockCount: false});
    expect(go(RoutePaths.stockCount, flags: noCount), RoutePaths.initial);
    expect(go(RoutePaths.stockCount), isNull);
  });

  test('dev page only in debug', () {
    expect(go(RoutePaths.devPlatform), RoutePaths.initial);
    expect(redirectFor(location: RoutePaths.devPlatform, session: FakeSession.ownerSession, flags: aisle, isDebug: true),
        isNull);
  });

  test('pattern matching prefers literal paths', () {
    expect(matchRoutePattern('/products/new'), RoutePaths.productNew);
    expect(matchRoutePattern('/products/abc/edit'), RoutePaths.productEdit);
    expect(matchRoutePattern('/prices/bulk'), RoutePaths.pricesBulk);
    expect(matchRoutePattern('/prices/abc'), RoutePaths.priceEdit);
    expect(matchRoutePattern('/dashboard'), isNull);
  });
}
