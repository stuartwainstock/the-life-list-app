import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Disk cache for species photos (thumbnails + detail gallery).
///
/// Separate from [DefaultCacheManager] and from map-tile caching so photo
/// eviction doesn't fight OSM tiles, and deliberately separate from
/// [EbirdListCache] JSON (offline sightings/hotspots) — see
/// `docs/tickets/app-footprint-and-cache-limits.md`.
///
/// Caps are object-count + age (flutter_cache_manager's model), tuned for
/// roughly tens of MB of Wikimedia images rather than unbounded growth.
class SpeciesImageCache {
  SpeciesImageCache._();

  static const _key = 'species_photos';

  /// ~100 images × typical Commons JPEG ≈ low tens of MB; unused files
  /// expire after three weeks.
  static final CacheManager instance = CacheManager(
    Config(
      _key,
      stalePeriod: const Duration(days: 21),
      maxNrOfCacheObjects: 100,
    ),
  );
}
