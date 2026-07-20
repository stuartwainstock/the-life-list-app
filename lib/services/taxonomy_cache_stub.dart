/// Web stub for taxonomy disk cache (selected via conditional import).
///
/// Flutter web can't use dart:io File the way mobile does. We intentionally
/// do **not** shove the multi‑MB taxonomy blob into SharedPreferences.
/// [EbirdTaxonomyService] still keeps an in-memory session cache, so web
/// grouping works after the first fetch in a session; it just won't survive
/// a full page reload the way the native disk cache does.
Future<String?> taxonomyDocumentsPath() async => null;

Future<String?> readTaxonomyCacheFile(String path) async => null;

Future<void> writeTaxonomyCacheFile(String path, String contents) async {}
