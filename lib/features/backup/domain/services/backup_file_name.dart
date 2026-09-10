// OWNER: A6.
/// Builds the names of the files this feature hands to the user.
///
/// Names are ASCII: an Arabic store name would survive on disk, but these
/// files travel by e-mail, WhatsApp and USB stick, where non-ASCII names are
/// still mangled. A store whose name has no ASCII letters falls back to the
/// start of its id, so two stores never produce the same name.
abstract final class BackupFileName {
  /// Double extension: `.json` so any tool opens it, `.shelfwise` so the app
  /// (and the owner) can tell it apart from other JSON.
  static const backupExtension = '.shelfwise.json';
  static const usageExtension = '-usage.csv';

  static String backup({
    required String brandId,
    required String storeName,
    required String storeId,
    required DateTime at,
  }) =>
      '${_prefix(brandId, storeName, storeId)}-${_stamp(at)}$backupExtension';

  static String usage({
    required String brandId,
    required String storeName,
    required String storeId,
    required DateTime at,
  }) =>
      '${_prefix(brandId, storeName, storeId)}-${_stamp(at)}$usageExtension';

  static String _prefix(String brandId, String storeName, String storeId) {
    final brand = _slug(brandId, fallback: 'shelfwise');
    final store = _slug(storeName, fallback: _slug(storeId, fallback: 'store'));
    return '$brand-$store';
  }

  /// Local time: the owner recognises "yesterday evening", not a UTC hour.
  static String _stamp(DateTime at) {
    final t = at.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}${two(t.month)}${two(t.day)}-${two(t.hour)}${two(t.minute)}';
  }

  static String _slug(String value, {required String fallback}) {
    final buffer = StringBuffer();
    var lastWasDash = false;
    for (final rune in value.toLowerCase().runes) {
      final isWord = (rune >= 0x61 && rune <= 0x7A) || (rune >= 0x30 && rune <= 0x39);
      if (isWord) {
        buffer.writeCharCode(rune);
        lastWasDash = false;
      } else if (!lastWasDash && buffer.isNotEmpty) {
        buffer.write('-');
        lastWasDash = true;
      }
    }
    var slug = buffer.toString();
    while (slug.endsWith('-')) {
      slug = slug.substring(0, slug.length - 1);
    }
    if (slug.length > 24) slug = slug.substring(0, 24).replaceAll(RegExp(r'-+$'), '');
    return slug.isEmpty ? fallback : slug;
  }
}
