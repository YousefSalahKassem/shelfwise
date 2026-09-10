// OWNER: A1 (replaces this stub). W0 ships a fake so the app runs.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'fake_session.dart';
import 'session_reader.dart';

part 'session_impl.g.dart';

/// Current session. A1 replaces the body with the real implementation
/// (store from DB, PIN unlock, auto-lock). Keep the provider name and state type.
@Riverpod(keepAlive: true)
class SessionController extends _$SessionController {
  @override
  SessionState build() => FakeSession.ownerSession;

  /// Dev/test helper until A1 lands.
  // ignore: use_setters_to_change_properties
  void debugSet(SessionState next) => state = next;
}
