// OWNER: A1. Real session: restores the store from the database, unlocks with a
// PIN and locks the app again after a period without user input.
import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/onboarding/data/store_providers.dart';
import '../../features/onboarding/domain/repositories/store_repository.dart';
import '../settings/preferences_impl.dart';
import '../utils/clock.dart';
import '../utils/core_providers.dart';
import 'session_reader.dart';

part 'session_impl.g.dart';

/// Who is using the app right now.
///
/// The app always starts **locked**: the store and its default branch are read
/// from the database, but a profile has to enter its PIN (TECHNICAL_STRUCTURE
/// §10). Before onboarding the state stays empty, which sends the router to
/// `/onboarding`.
@Riverpod(keepAlive: true)
class SessionController extends _$SessionController {
  _IdleWatchdog? _watchdog;

  /// Completes once the store has been read from the database. Screens that
  /// would otherwise flash (onboarding) wait for it; nothing else needs to.
  Future<void> restored = Future<void>.value();

  @override
  SessionState build() {
    final watchdog = _IdleWatchdog(
      clock: ref.read(clockProvider),
      timeout: _timeoutFrom(ref.read(preferencesControllerProvider).autoLockMinutes),
      onIdle: lock,
    );
    _watchdog = watchdog;
    ref.listen(preferencesControllerProvider, (_, next) {
      watchdog.timeout = _timeoutFrom(next.autoLockMinutes);
    });
    ref.onDispose(watchdog.dispose);

    restored = _restore();
    return SessionState.empty;
  }

  Future<void> _restore() async {
    final StoreRepository repository;
    try {
      repository = ref.read(storeRepositoryProvider);
    } on Object {
      // No database: widget tests that don't exercise persistence. Riverpod
      // wraps the original error, so the catch has to be broad.
      return;
    }
    final store = (await repository.getCurrent()).valueOrNull;
    if (store == null || !ref.mounted) return;
    final branch = (await repository.getDefaultBranch()).valueOrNull;
    if (!ref.mounted) return;
    state = SessionState(store: store, branch: branch, locked: true);
  }

  /// First run: onboarding created the store and signed the owner in.
  void startSession(StoreSetup setup) {
    state = SessionState(store: setup.store, branch: setup.branch, profile: setup.owner);
    _watchdog?.arm();
  }

  /// A profile passed the lock screen.
  void unlock(Profile profile) {
    state = SessionState(store: state.store, branch: state.branch, profile: profile);
    _watchdog?.arm();
  }

  /// Back to the lock screen — from the settings screen, or after idle time.
  void lock() {
    if (!state.hasStore || state.locked) return;
    state = SessionState(
      store: state.store,
      branch: state.branch,
      profile: state.profile,
      locked: true,
    );
    _watchdog?.disarm();
  }

  /// The store name or currency changed in settings.
  void applyStore(Store store) => state = state.copyWith(store: store);

  /// The signed-in profile was renamed, re-languaged or deactivated.
  void applyProfile(Profile profile) {
    if (state.profile?.id != profile.id) return;
    if (!profile.isActive) {
      state = SessionState(store: state.store, branch: state.branch, locked: true);
      _watchdog?.disarm();
      return;
    }
    state = state.copyWith(profile: profile);
  }

  static Duration? _timeoutFrom(int minutes) =>
      minutes <= 0 ? null : Duration(minutes: minutes);
}

/// Whether the store has been read from the database yet. The onboarding page
/// shows a spinner until then so it never flashes on an already-set-up device.
@Riverpod(keepAlive: true)
Future<void> sessionRestore(Ref ref) => ref.watch(sessionControllerProvider.notifier).restored;

/// Locks the app after [timeout] without a pointer or keyboard event.
///
/// Listening globally (rather than wrapping the widget tree) keeps `app.dart`
/// and the navigation shell — both owned by the lead — untouched.
class _IdleWatchdog {
  _IdleWatchdog({required this.clock, required this.timeout, required this.onIdle});

  final Clock clock;
  final VoidCallback onIdle;

  Duration? timeout;
  Timer? _timer;
  DateTime? _lastActivity;
  AppLifecycleListener? _lifecycle;
  bool _listening = false;

  void arm() {
    _listen();
    _lastActivity = clock.now();
    _schedule();
  }

  void disarm() {
    _timer?.cancel();
    _timer = null;
    _lastActivity = null;
  }

  void dispose() {
    disarm();
    _stopListening();
  }

  void _listen() {
    if (_listening) return;
    final binding = _binding;
    if (binding == null) return;
    binding.pointerRouter.addGlobalRoute(_onPointer);
    HardwareKeyboard.instance.addHandler(_onKey);
    _lifecycle = AppLifecycleListener(onResume: _check);
    _listening = true;
  }

  void _stopListening() {
    if (!_listening) return;
    _binding?.pointerRouter.removeGlobalRoute(_onPointer);
    HardwareKeyboard.instance.removeHandler(_onKey);
    _lifecycle?.dispose();
    _lifecycle = null;
    _listening = false;
  }

  void _onPointer(PointerEvent event) {
    if (event is PointerDownEvent || event is PointerMoveEvent || event is PointerUpEvent) {
      _touch();
    }
  }

  bool _onKey(KeyEvent event) {
    _touch();
    return false;
  }

  void _touch() {
    if (_lastActivity == null) return; // Not armed: already locked.
    _lastActivity = clock.now();
    _schedule();
  }

  /// Timers don't run while the app is in the background on every platform, so
  /// the elapsed time is re-checked whenever the app comes back.
  void _check() {
    final last = _lastActivity;
    final limit = timeout;
    if (last == null || limit == null) return;
    if (clock.now().difference(last) >= limit) {
      disarm();
      onIdle();
    } else {
      _schedule();
    }
  }

  void _schedule() {
    _timer?.cancel();
    final last = _lastActivity;
    final limit = timeout;
    if (last == null || limit == null) {
      _timer = null;
      return;
    }
    final remaining = limit - clock.now().difference(last);
    _timer = Timer(remaining.isNegative ? Duration.zero : remaining, _check);
  }

  static GestureBinding? get _binding {
    try {
      return GestureBinding.instance;
    } on Object {
      return null; // No Flutter binding (plain unit tests).
    }
  }
}
