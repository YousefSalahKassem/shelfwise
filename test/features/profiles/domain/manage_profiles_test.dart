import 'package:flutter_test/flutter_test.dart';
import 'package:shelfwise/core/analytics/analytics_service.dart';
import 'package:shelfwise/core/auth/permission.dart';
import 'package:shelfwise/core/brand/feature_flags.dart';
import 'package:shelfwise/core/brand/tier.dart';
import 'package:shelfwise/core/error/failure.dart';
import 'package:shelfwise/core/error/result.dart';
import 'package:shelfwise/core/session/fake_session.dart';
import 'package:shelfwise/core/session/session_reader.dart';
import 'package:shelfwise/core/utils/clock.dart';
import 'package:shelfwise/features/profiles/domain/usecases/manage_profiles.dart';
import 'package:shelfwise/features/profiles/domain/usecases/unlock_profile.dart';
import 'package:shelfwise/features/profiles/domain/value_objects/pin.dart';

import '../../../helpers/fixtures.dart';
import '../support/fake_profile_repository.dart';

void main() {
  const shelf = FeatureFlags(tier: Tier.shelf); // 3 staff profiles
  const aisle = FeatureFlags(tier: Tier.aisle); // unlimited

  late FakeProfileRepository repository;

  setUp(() => repository = FakeProfileRepository());
  tearDown(() => repository.dispose());

  CreateStaffProfile creator({SessionState session = FakeSession.ownerSession, FeatureFlags flags = aisle}) =>
      CreateStaffProfile(repository: repository, session: session, flags: flags);

  group('permissions', () {
    test('staff cannot add, edit, reset or deactivate profiles', () async {
      const session = FakeSession.staffSession;
      final results = <Result<Object?>>[
        await creator(session: session)(name: 'Sara', pin: '1234'),
        await UpdateProfile(repository: repository, session: session, flags: aisle)(
          FakeSession.staff.copyWith(name: 'Nope'),
        ),
        await ResetPin(repository: repository, session: session)(FakeSession.staff.id, '1111'),
        await DeactivateProfile(repository: repository, session: session)(FakeSession.staff.id),
      ];
      for (final result in results) {
        expect(result.failureOrNull, isA<PermissionFailure>());
      }
    });

    test('a locked owner cannot manage profiles either', () async {
      final result = await creator(session: FakeSession.locked)(name: 'Sara', pin: '1234');
      expect(result.failureOrNull, isA<PermissionFailure>());
    });

    test('the owner can add a staff profile', () async {
      final result = await creator()(name: '  Sara  ', pin: '1234', locale: 'ar');
      expect(result.valueOrNull?.name, 'Sara');
      expect(result.valueOrNull?.role, Role.staff);
      expect(result.valueOrNull?.locale, 'ar');
    });
  });

  group('validation', () {
    test('a name is required', () async {
      final result = await creator()(name: '   ', pin: '1234');
      expect(result.failureOrNull, isA<ValidationFailure>().having((f) => f.field, 'field', 'name'));
    });

    test('the PIN must be 4 to 6 digits', () async {
      for (final pin in ['123', '1234567', '12a4']) {
        final result = await creator()(name: 'Sara', pin: pin);
        expect(
          result.failureOrNull,
          isA<ValidationFailure>().having((f) => f.code, 'code', PinFailureCodes.length),
          reason: pin,
        );
      }
    });
  });

  group('staff limit', () {
    test('the shelf tier allows three staff profiles and blocks the fourth', () async {
      // Start from a store that has only its owner.
      repository = FakeProfileRepository(profiles: [FakeSession.owner], pins: {});
      for (var i = 1; i <= 3; i++) {
        final result = await creator(flags: shelf)(name: 'Staff $i', pin: '1234');
        expect(result.isSuccess, isTrue, reason: 'staff $i');
      }

      final blocked = await creator(flags: shelf)(name: 'Staff 4', pin: '1234');
      expect(
        blocked.failureOrNull,
        isA<FeatureLockedFailure>().having((f) => f.feature, 'feature', staffLimitFeature),
      );
    });

    test('the aisle tier has no limit', () async {
      for (var i = 1; i <= 5; i++) {
        expect((await creator(flags: aisle)(name: 'Staff $i', pin: '1234')).isSuccess, isTrue);
      }
    });

    test('the owner does not count towards the staff limit', () async {
      // The fixture already has one owner and one staff profile.
      expect((await creator(flags: shelf)(name: 'B', pin: '1234')).isSuccess, isTrue);
      expect((await creator(flags: shelf)(name: 'C', pin: '1234')).isSuccess, isTrue);
      expect((await creator(flags: shelf)(name: 'D', pin: '1234')).isSuccess, isFalse);
    });

    test('deactivating frees a slot, and reactivating is blocked when it is full', () async {
      await creator(flags: shelf)(name: 'B', pin: '1234');
      await creator(flags: shelf)(name: 'C', pin: '1234');

      const owner = FakeSession.ownerSession;
      await DeactivateProfile(repository: repository, session: owner)(FakeSession.staff.id);
      expect((await creator(flags: shelf)(name: 'D', pin: '1234')).isSuccess, isTrue);

      final reactivate = await UpdateProfile(repository: repository, session: owner, flags: shelf)(
        FakeSession.staff.copyWith(isActive: true),
      );
      expect(reactivate.failureOrNull, isA<FeatureLockedFailure>());
    });
  });

  test('the owner profile can never be deactivated', () async {
    final result = await DeactivateProfile(
      repository: repository,
      session: FakeSession.ownerSession,
    )(FakeSession.owner.id);

    expect(
      result.failureOrNull,
      isA<ValidationFailure>().having((f) => f.code, 'code', 'owner_protected'),
    );
  });

  group('unlock', () {
    late RecordingAnalyticsService analytics;
    late UnlockProfile unlock;

    setUp(() {
      analytics = RecordingAnalyticsService();
      unlock = UnlockProfile(
        repository: repository,
        analytics: analytics,
        clock: FixedClock(Fixtures.now),
      );
    });

    test('the right PIN unlocks and logs session_started', () async {
      final result = await unlock(FakeSession.owner.id, '1234', switching: false);
      expect(result.valueOrNull?.id, FakeSession.owner.id);
      expect(analytics.events.single.$1, AppEvent.sessionStarted);
    });

    test('unlocking while another profile was signed in logs profile_switched', () async {
      await unlock(FakeSession.staff.id, '5678', switching: true);
      expect(analytics.events.single.$1, AppEvent.profileSwitched);
    });

    test('a wrong PIN is rejected and logs nothing', () async {
      final result = await unlock(FakeSession.owner.id, '9999', switching: false);
      expect(
        result.failureOrNull,
        isA<ValidationFailure>().having((f) => f.code, 'code', PinFailureCodes.wrongPin),
      );
      expect(analytics.events, isEmpty);
    });

    test('a deactivated profile cannot unlock', () async {
      await DeactivateProfile(repository: repository, session: FakeSession.ownerSession)(
        FakeSession.staff.id,
      );
      final result = await unlock(FakeSession.staff.id, '5678', switching: false);
      expect(result.isSuccess, isFalse);
    });

    test('five wrong PINs freeze the profile for 30 seconds', () async {
      for (var i = 0; i < 5; i++) {
        await unlock(FakeSession.owner.id, '9999', switching: false);
      }

      expect(unlock.cooldownSeconds(FakeSession.owner.id), 30);
      final duringCooldown = await unlock(FakeSession.owner.id, '1234', switching: false);
      expect(
        duringCooldown.failureOrNull,
        isA<ValidationFailure>().having((f) => f.code, 'code', PinFailureCodes.lockedOut),
      );

      (unlock.clock as FixedClock).advance(const Duration(seconds: 31));
      expect(unlock.cooldownSeconds(FakeSession.owner.id), isNull);
      expect((await unlock(FakeSession.owner.id, '1234', switching: false)).isSuccess, isTrue);
    });

    test('a PIN of the wrong length counts as a wrong attempt', () async {
      for (var i = 0; i < 5; i++) {
        await unlock(FakeSession.owner.id, '1', switching: false);
      }
      expect(unlock.cooldownSeconds(FakeSession.owner.id), 30);
    });
  });
}
