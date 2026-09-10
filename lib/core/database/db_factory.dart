/// Picks the right sqflite factory per platform (TECHNICAL_STRUCTURE §6):
/// - Android / iOS / macOS → sqflite plugin
/// - Windows / Linux       → sqflite_common_ffi
/// - Web                   → sqflite_common_ffi_web (IndexedDB, experimental)
library;

export 'db_factory_stub.dart'
    if (dart.library.io) 'db_factory_io.dart'
    if (dart.library.js_interop) 'db_factory_web.dart';
