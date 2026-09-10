// OWNER: A6.
import 'dart:js_interop';

import 'storage_persistence_result.dart';

/// Asks the browser to keep the IndexedDB database that holds the store's data
/// (TECHNICAL_STRUCTURE §6). Chrome grants this silently for installed or
/// frequently used sites; other browsers may refuse, and then the app warns
/// the owner to back up.
Future<StoragePersistence> requestStoragePersistence() async {
  try {
    final storage = webNavigator.storage;
    if (storage == null) return StoragePersistence.unsupported;
    if ((await storage.persisted().toDart).toDart) return StoragePersistence.granted;
    final granted = (await storage.persist().toDart).toDart;
    return granted ? StoragePersistence.granted : StoragePersistence.denied;
  } on Object {
    // Old browsers, private windows and insecure origins all throw here.
    return StoragePersistence.unsupported;
  }
}

@JS('navigator')
external WebNavigator get webNavigator;

extension type WebNavigator._(JSObject _) implements JSObject {
  external StorageManager? get storage;
}

extension type StorageManager._(JSObject _) implements JSObject {
  external JSPromise<JSBoolean> persisted();
  external JSPromise<JSBoolean> persist();
}
