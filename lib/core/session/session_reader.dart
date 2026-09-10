import 'package:meta/meta.dart';

import '../auth/permission.dart';
import 'entities/branch.dart';
import 'entities/profile.dart';
import 'entities/store.dart';

export 'entities/branch.dart';
export 'entities/profile.dart';
export 'entities/store.dart';

/// Read-only view of who is using the app, for use cases and guards.
abstract interface class SessionReader {
  Store? get store;
  Branch? get branch;
  Profile? get profile;

  /// A store exists (onboarding done).
  bool get hasStore;

  /// A profile has entered its PIN and the app isn't locked.
  bool get isUnlocked;

  bool can(Permission permission);
}

/// Immutable session snapshot exposed by `sessionControllerProvider`.
@immutable
class SessionState implements SessionReader {
  const SessionState({this.store, this.branch, this.profile, this.locked = false});

  static const empty = SessionState();

  @override
  final Store? store;
  @override
  final Branch? branch;
  @override
  final Profile? profile;
  final bool locked;

  @override
  bool get hasStore => store != null;

  @override
  bool get isUnlocked => profile != null && !locked;

  @override
  bool can(Permission permission) {
    final p = profile;
    if (p == null || !p.isActive || locked) return false;
    return defaultRolePermissions[p.role]?.contains(permission) ?? false;
  }

  SessionState copyWith({Store? store, Branch? branch, Profile? profile, bool? locked}) =>
      SessionState(
        store: store ?? this.store,
        branch: branch ?? this.branch,
        profile: profile ?? this.profile,
        locked: locked ?? this.locked,
      );

  @override
  bool operator ==(Object other) =>
      other is SessionState &&
      other.store == store &&
      other.branch == branch &&
      other.profile == profile &&
      other.locked == locked;

  @override
  int get hashCode => Object.hash(store, branch, profile, locked);
}
