import '../auth/permission.dart';
import 'session_reader.dart';

/// Ready-made sessions for development and tests.
abstract final class FakeSession {
  static const store = Store(id: 'store-1', name: 'Demo Market', currency: 'EGP', locale: 'en');
  static const branch = Branch(id: 'branch-1', storeId: 'store-1', name: 'Main', isDefault: true);
  static const owner = Profile(id: 'profile-owner', storeId: 'store-1', name: 'Karim', role: Role.owner);
  static const staff = Profile(id: 'profile-staff', storeId: 'store-1', name: 'Mona', role: Role.staff);

  static const SessionState ownerSession = SessionState(store: store, branch: branch, profile: owner);
  static const SessionState staffSession = SessionState(store: store, branch: branch, profile: staff);
  static const SessionState locked = SessionState(store: store, branch: branch, locked: true);
  static const SessionState noStore = SessionState();
}
