import 'package:flutter_map/flutter_map.dart';

/// Bounded OSM tile disk cache for [flutter_map]'s built-in provider.
///
/// Call [ensureConfigured] once at app start (before any [TileLayer] loads)
/// so we don't inherit the library default of 1 GB. Separate from species
/// photo cache and from [EbirdListCache] JSON.
///
/// See `docs/tickets/app-footprint-and-cache-limits.md`.
abstract final class MapTileCache {
  /// Soft cap applied when the provider instance is first created.
  static const int maxCacheBytes = 50 * 1024 * 1024; // 50 MB

  /// How long a cached tile stays "fresh" regardless of HTTP headers.
  static const Duration freshAge = Duration(days: 14);

  static bool _configured = false;

  /// Idempotent — safe to call from [main] and again from the map screen.
  static void ensureConfigured() {
    if (_configured) return;
    BuiltInMapCachingProvider.getOrCreateInstance(
      maxCacheSize: maxCacheBytes,
      overrideFreshAge: freshAge,
    );
    _configured = true;
  }
}
