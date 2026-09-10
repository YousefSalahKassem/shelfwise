// OWNER: A6. Picks the browser implementation on web, a no-op elsewhere
// (same pattern as `core/database/db_factory.dart`).
library;

export 'storage_persistence_result.dart';
export 'storage_persistence_stub.dart'
    if (dart.library.io) 'storage_persistence_io.dart'
    if (dart.library.js_interop) 'storage_persistence_web.dart'
    show requestStoragePersistence;
