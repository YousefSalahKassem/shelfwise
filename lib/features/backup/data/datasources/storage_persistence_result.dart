// OWNER: A6.
/// Whether the browser promised to keep this store's data.
enum StoragePersistence {
  /// Not a browser (or the browser has no Storage API): the database is a
  /// normal file and the operating system won't quietly delete it.
  unsupported,

  /// The browser marked the origin as persistent.
  granted,

  /// The browser refused: it may clear the database when space runs low,
  /// so backups are the only safety net (TECHNICAL_STRUCTURE §6).
  denied,
}
