/// Web stub for eBird list disk cache (selected via conditional import).
///
/// Same rationale as taxonomy_cache_stub: no durable dart:io documents path.
/// [EbirdListCache] degrades to network-only on web (no stale-while-revalidate
/// across reloads).
Future<String?> listCacheDocumentsPath() async => null;

Future<String?> readListCacheFile(String path) async => null;

Future<void> writeListCacheFile(String path, String contents) async {}
